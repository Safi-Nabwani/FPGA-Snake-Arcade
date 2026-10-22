"""Deterministic supplied-ZIP menu integration. No generated artwork.

--install writes only the new opening ROMs/layout include. --fixtures generates
independent native-screen expectations. --build-results checks the single build.
The existing HUD, gameplay and all original MIFs are read-only.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys
import zipfile

sys.dont_write_bytecode=True
from PIL import Image
from build_jungle_assets import parse_mif,rgb
from implement_final_hud import inspect_build,numbers

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/jungle/supplied_opening'
OUT=ROOT/'assets/jungle/supplied_opening_implemented'
MIFS=ROOT/'RTL/mifs'
SHAS={
    'user_reference_background_126x120.png':'aa2c1e1dde1f6affb07d8950bf2481c4196e663e5b573c19d5d88912db3189da',
    'overgrown_temple_torchlit_frame.png':'3a0ade6ac9bc4c82cc958c1e0fb90715b226b2f0392ee14f04c24217c6636936',
    'snake_arcade_temple_menu.png':'8520589e981263c08c0962132745548f0d24bc054b0e95afa457935bce1e0787',
}
# Rectangles in the supplied menu after its exact496x480 adaptation. Tight native
# patches retain supplied text, icons and keycaps, not a newly invented font/art.
PATCHES=[
    ('title',120,58,264,108),
    ('controls_heading',34,204,116,25),
    ('keys',37,238,105,98),
    ('control_caption',20,338,140,36),
    ('relics_heading',194,204,120,25),
    ('ruby',196,236,134,43),
    ('sapphire',196,281,134,42),
    ('cursed',190,328,140,44),
    ('goal_heading',389,204,76,25),
    ('goal',379,242,94,110),
    ('start',100,414,296,34),
]


def encode(image):
    return [(round(r*7/255)<<5)|(round(g*7/255)<<2)|round(b*3/255) for r,g,b in image.convert('RGB').get_flattened_data()]


def write_mif(path,depth,data):
    if path.name=='opening_supplied_atlas.mif' and (ROOT/'assets/jungle/approved_opening/manifest.json').exists():
        raise RuntimeError('Approved opening protected: use scripts/integrate_approved_opening.py; historical regeneration must not overwrite it')
    assert len(data)==depth
    path.write_text('WIDTH=8;\nDEPTH='+str(depth)+';\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n'+
                    ''.join(f'{i} : {v:02X};\n' for i,v in enumerate(data))+'END;\n',encoding='ascii')


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--install',action='store_true')
    p.add_argument('--fixtures',action='store_true')
    p.add_argument('--preview',action='store_true')
    p.add_argument('--zip',type=Path)
    p.add_argument('--build-results',type=Path)
    args=p.parse_args()
    for name,sha in SHAS.items():
        assert hashlib.sha256((ASSETS/name).read_bytes()).hexdigest()==sha,'Supplied source changed: '+name
    if args.zip:
        with zipfile.ZipFile(args.zip) as z:
            for name in SHAS:assert z.read(name)==(ASSETS/name).read_bytes()
    # Native composition uses ONLY supplied frame + main concept. Alpha is real
    # source alpha, not RGB000000 transparency. Fit the matching aspect without crop.
    frame=Image.open(ASSETS/'overgrown_temple_torchlit_frame.png').convert('RGBA').resize((496,480),Image.Resampling.NEAREST)
    concept=Image.open(ASSETS/'snake_arcade_temple_menu.png').convert('RGBA').resize((496,480),Image.Resampling.NEAREST)
    native=Image.alpha_composite(frame,concept).convert('RGB')
    source_codes=encode(native)
    # Use exact4x pixels in the right496x480 area. No divider in the FPGA.
    background=native.resize((124,120),Image.Resampling.BOX)
    bg=encode(background)
    atlas=[];regions=[];coverage=set()
    # Quantize before expansion so all four displayed pixels share one RGB332 code.
    background.putdata([rgb(v) for v in bg]);right=background.resize((496,480),Image.Resampling.NEAREST)
    for name,x,y,w,h in PATCHES:
        assert 0<=x and x+w<=496 and 0<=y and y+h<=480
        offset=len(bg)+len(atlas)
        patch=[source_codes[yy*496+xx] for yy in range(y,y+h) for xx in range(x,x+w)]
        for yy in range(y,y+h):
            for xx in range(x,x+w):
                assert (xx,yy) not in coverage,'overlapping patch storage'
                coverage.add((xx,yy))
        atlas.extend(patch)
        tile=Image.new('RGB',(w,h));tile.putdata([rgb(v) for v in patch]);right.paste(tile,(x,y))
        regions.append(dict(name=name,x=x,y=y,width=w,height=h,offset=offset))
    combined=bg+atlas
    aw=(len(combined)-1).bit_length()
    atlas_path=MIFS/'opening_supplied_atlas.mif'
    if args.install:
        write_mif(atlas_path,len(combined),combined)
        lines=['// Generated from supplied ZIP artwork only. Right-local coordinates; no HUD coverage.',
               f'localparam int MENU_ROM_DEPTH={len(combined)};',f'localparam int MENU_ADDRESS_WIDTH={aw};',
               'always_comb begin',f"    menuAddress={{{{{aw-14}{{1'b0}}}},menuBackgroundAddress}};"]
        for region in regions:
            n,x,y,w,h,o=[region[k] for k in ['name','x','y','width','height','offset']]
            # Correctly sized positive shifts/additions for each constant row stride.
            row=f"({{{{{aw-9}{{1'b0}}}}, menuY}} - {aw}'d{y})"
            terms=[f'({row} << {bit})' if bit else row for bit in range(w.bit_length()) if (w>>bit)&1]
            expression=' + '.join(terms)
            lines.extend([f'    // {n}',f"    if(menuVisible && menuX>=9'd{x} && menuX<9'd{x+w} && menuY>=9'd{y} && menuY<9'd{y+h}) begin",
                          f"        menuAddress={aw}'d{o} + {expression} + {{{{{aw-9}{{1'b0}}}},menuX}} - {aw}'d{x};",'    end'])
        lines.extend(['end',''])
        (ROOT/'RTL/VGA/opening_supplied_layout.svh').write_text('\n'.join(lines),encoding='ascii')
    assert parse_mif(atlas_path.read_text())==(8,len(combined),combined)
    # Decode actual active MIFs at every output pixel for independent preview/fixture.
    actual=Image.new('RGB',(640,480),rgb(0))
    pixel_codes=[0]*307200
    for y in range(480):
        for x in range(144,640):
            mx=x-144; value=bg[(y>>2)*124+(mx>>2)]
            for r in regions:
                if r['x']<=mx<r['x']+r['width'] and r['y']<=y<r['y']+r['height']:
                    value=combined[r['offset']+(y-r['y'])*r['width']+mx-r['x']];break
            pixel_codes[y*640+x]=value
    actual.putdata([rgb(v) for v in pixel_codes])
    assert actual.crop((144,0,640,480)).tobytes()==right.tobytes()
    # Composite the UNMODIFIED existing HUD ROM and font, only x<144.
    _,_,panel=parse_mif((MIFS/'hud_frame_rgb332.mif').read_text())
    _,_,font=parse_mif((MIFS/'numbers_new_font.mif').read_text())
    for y in range(480):
        for x in range(144):actual.putpixel((x,y),rgb(panel[y*144+x]))
    actual=numbers(actual,font,['00','00','000','000','000'])
    hud_reference=Image.open(ROOT/'assets/jungle/hud_final_implemented/zero_values_640x480.png').convert('RGB')
    assert actual.crop((0,0,144,480)).tobytes()==hud_reference.crop((0,0,144,480)).tobytes(),'Existing HUD changed'
    if args.fixtures:
        fixture=ROOT/'db/supplied_opening_fixture';fixture.mkdir(parents=True,exist_ok=True)
        (fixture/'expected.hex').write_text(''.join(f'{v:02x}\n' for v in pixel_codes))
        (fixture/'composite.hex').write_text(''.join(f'{v:02x}\n' for v in encode(actual)))
        legacy=subprocess.check_output(['git','show','59beeed:RTL/VGA/End_Message_Display.sv'],cwd=ROOT)
        (fixture/'legacy_end_message_display.sv').write_bytes(legacy.replace(b'module end_message_display (',b'module legacy_end_message_display (',1))
    if args.preview:
        OUT.mkdir(parents=True,exist_ok=True)
        background.save(OUT/'background_124x120.png')
        right.save(OUT/'right_area_496x480.png')
        actual.save(OUT/'full_scene_640x480.png')
        actual.resize((1280,960),Image.Resampling.NEAREST).save(OUT/'full_scene_2x.png')
        meta=dict(source_sha256=SHAS,sidebar_bounds=[0,0,144,480],menu_bounds=[144,0,640,480],
                  background_pixels=len(bg),native_detail_pixels=len(atlas),detail_address_width=aw,
                  regions=regions,total_bits=8*(len(bg)+len(atlas)),
                  estimated_menu_blocks=(len(combined)+1023)//1024,
                  estimated_project_blocks=515-300+(len(combined)+1023)//1024,
                  estimate_not_fitted=True,existing_hud_pixel_identical=True,alpha_composited=True,
                  supplied_files_only=True)
        (OUT/'verification.json').write_text(json.dumps(meta,indent=2)+'\n')
    if args.build_results:
        result=inspect_build(args.build_results)
        report=(args.build_results/'Lab1Demo.fit.rpt').read_text().split('; Fitter RAM Summary',1)[1]
        rows=[[part.strip() for part in line.split(';')[1:-1]] for line in report.splitlines() if line.startswith(';')]
        header=next(row for row in rows if row[0]=='Name')
        allocation=[dict(zip(header,row)) for row in rows if len(row)==len(header) and row[2]=='ROM']
        opening=next(row for row in allocation if row['MIF']=='RTL/mifs/opening_supplied_atlas.mif')
        total_locations=set().union(*(set(re.findall(r'M10K_X\d+_Y\d+_N\d+',row['Location'])) for row in allocation))
        opening_locations=set(re.findall(r'M10K_X\d+_Y\d+_N\d+',opening['Location']))
        assert len(total_locations)<515 and len(opening_locations)<300,'No measured memory reduction'
        measurement=dict(baseline=inspect_build(ROOT/'db/win90_build/source/output_files'),current=result,
                         measured_total_m10k=len(total_locations),measured_opening_m10k=len(opening_locations),
                         opening_rom={k:v for k,v in opening.items() if k!='Location'},all_reported_timing_positive=True,
                         atlas_sha256=hashlib.sha256(atlas_path.read_bytes()).hexdigest())
        OUT.mkdir(parents=True,exist_ok=True)
        (OUT/'quartus_results.json').write_text(json.dumps(measurement,indent=2)+'\n')
        print(json.dumps(measurement,indent=2))
    print(f'SUPPLIED_OPENING_PASS:496x480 right area; unchanged144x480 HUD; {len(bg)}background + {len(atlas)}native pixels; RGB332; no generated artwork')


if __name__=='__main__':main()
