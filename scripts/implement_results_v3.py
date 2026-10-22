"""Exact approved V3 results assets; lossless storage and independent verification."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import zipfile

sys.dont_write_bytecode=True
from PIL import Image
from build_jungle_assets import parse_mif, rgb
from implement_final_hud import arena_scene, numbers, REGIONS, inspect_build

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/jungle/results_v3_supplied'
OUT=ROOT/'assets/jungle/results_v3_implemented'
MIFS=ROOT/'RTL/mifs/results_v3'
FIX=ROOT/'db/results_v3_fixture'
ARCHIVE=Path('C:/Users/USER/Downloads/FPGA_Snake_Phase3D_Approved_Results_Codex.zip')
# Report-only placements inside measured exact-black empty wells. HUD unchanged.
# Final score first (Defeat only), then Ruby/Sapphire/Cursed.
FIELDS={
    'victory':[(438,290,3,0xED),(437,331,3,0x57),(437,371,3,0xB3)],
    'defeat':[(443,230,2,0xF9),(431,286,3,0xED),(431,324,3,0x57),(431,363,3,0xB3)]}
FONT_X=[((2*x+1)*16)//24 for x in range(12)]
FONT_Y=[6+((2*y+1)*18)//28 for y in range(14)]


def write_mif(path,width,values):
    if path.name=='opening_supplied_atlas.mif' and (ROOT/'assets/jungle/approved_opening/manifest.json').exists():
        raise RuntimeError('Approved opening protected: use scripts/integrate_approved_opening.py; historical regeneration must not overwrite it')
    path.write_text(f'WIDTH={width};\nDEPTH={len(values)};\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n'+
        ''.join(f'{i} : {v:X};\n' for i,v in enumerate(values))+'END;\n',encoding='ascii')


def sha(data):return hashlib.sha256(data).hexdigest()


def read_image(base,folder):
    bits,depth,colors=parse_mif((folder/(base+'_rgb332.mif')).read_text())
    mask_bits,mask_depth,masks=parse_mif((folder/(base+'_mask1.mif')).read_text())
    assert bits==8 and mask_bits==1 and depth==mask_depth
    return colors,masks


def png_check(path,w,h,colors,masks):
    image=Image.open(path).convert('RGBA')
    assert image.size==(w,h) and len(colors)==w*h
    pixels=list(image.get_flattened_data())
    codes=[(round(r*7/255)<<5)|(round(g*7/255)<<2)|round(b*3/255) for r,g,b,a in pixels]
    assert codes==colors, 'PNG/MIF colors differ: '+str(path)
    assert all(a in (0,255) for r,g,b,a in pixels)
    assert [int(a!=0) for r,g,b,a in pixels]==masks, 'PNG/MIF masks differ: '+str(path)
    assert pixels==[(*rgb(v),255*m) for v,m in zip(colors,masks)],'Exact decoded PNG RGBA differs: '+str(path)


def assets():
    if ARCHIVE.exists():
        with zipfile.ZipFile(ARCHIVE) as archive:
            for entry in archive.infolist():
                assert (SOURCE/entry.filename).read_bytes()==archive.read(entry),'Supplied file changed: '+entry.filename
    manifest=json.loads((SOURCE/'manifest.json').read_text())
    split={}
    for name,desc in manifest['assets'].items():
        for filename,key in [(desc['color_mif'],'color_sha256'),(desc['mask_mif'],'mask_sha256')]:
            assert sha((SOURCE/'rom'/filename).read_bytes())==desc[key]
        colors,masks=read_image(name,SOURCE/'rom')
        w,h=desc['dimensions'];assert len(colors)==desc['depth'] and sum(masks)==desc['opaque_pixels']
        png_check(SOURCE/'rom'/desc['png'],w,h,colors,masks)
        split[name]=(colors,masks)
    full={}
    for state in ['victory','defeat']:
        name=state+'_full_288x432'
        colors,masks=read_image(name,SOURCE/'reference_full_mifs')
        png_check(SOURCE/'source/approved_vga_panels'/(name+'_RGB332_RGBA.png'),288,432,colors,masks)
        full[state]=(colors,masks)
        sc,sm=split[state+'_upper_288x252'];lc,lm=split['shared_lower_288x180']
        differences=sum((a,b)!=(c,d) for a,b,c,d in zip(colors,masks,sc+lc,sm+lm))
        assert differences==manifest['comparison'][state]['different_pixels_vs_independently_approved_panel']
    return full


def tiled(full,size):
    dictionary=[];lookup={};tilemap=[]
    for state in ['victory','defeat']:
        colors,masks=full[state]
        for ty in range(0,432,size):
            for tx in range(0,288,size):
                key=tuple((masks[(ty+y)*288+tx+x]<<8)|colors[(ty+y)*288+tx+x]
                          for y in range(size) for x in range(size))
                if key not in lookup:
                    lookup[key]=len(lookup);dictionary.extend(key)
                tilemap.append(lookup[key])
    return dictionary,tilemap,len(lookup)


def largest_black_rect(colors,region):
    # Find an exact empty numeral well without changing approved artwork.
    left,top,right,bottom=region;heights=[0]*(right-left);best=(0,None)
    for y in range(top,bottom):
        heights=[h+1 if colors[y*288+left+x]==0 else 0 for x,h in enumerate(heights)]
        stack=[]
        for x,h in enumerate(heights+[0]):
            start=x
            while stack and stack[-1][1]>h:
                start,old_h=stack.pop();area=(x-start)*old_h
                if area>best[0]:best=(area,(left+start,y-old_h+1,left+x,y+1))
            if not stack or stack[-1][1]<h:stack.append((start,h))
    return best


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--inspect',action='store_true')
    parser.add_argument('--install',action='store_true')
    parser.add_argument('--preview',action='store_true')
    parser.add_argument('--audit',action='store_true')
    parser.add_argument('--git-index',action='store_true')
    parser.add_argument('--build-results',type=Path)
    args=parser.parse_args()
    if args.git_index:
        expected={'.gitattributes','RTL/VGA/results_report_renderer.svh',
                  'simulation/results_reports_tb.sv','simulation/results_reports.do',
                  'scripts/implement_results_v3.py','RESULTS_SCREEN_V3_IMPLEMENTATION.md'}
        for folder in [MIFS,SOURCE,OUT]:
            expected.update(p.relative_to(ROOT).as_posix() for p in folder.rglob('*') if p.is_file())
        staged=set(subprocess.check_output(['git','diff','--cached','--name-only'],cwd=ROOT).decode().splitlines())
        assert staged==expected,f'Unexpected/missing staged files: {staged ^ expected}'
        for name in sorted(staged):
            contents=subprocess.check_output(['git','show',':'+name],cwd=ROOT)
            active=(ROOT/name).read_bytes()
            if name.startswith(('RTL/mifs/results_v3/','assets/jungle/results_v3_supplied/')) or name.endswith('.png'):
                assert contents==active,'Staged asset byte mismatch: '+name
            else:assert contents.replace(b'\r\n',b'\n')==active.replace(b'\r\n',b'\n'),'Staged source mismatch: '+name
        print(f'GIT_INDEX_PASS:exactly{len(staged)} task files; supplied bytes exact; QSF/BDF/user edits excluded')
    full=assets()
    alternatives=[]
    for size in [1,2,4,8,16]:
        dictionary,tilemap,unique=tiled(full,size)
        bits=(unique-1).bit_length()
        # Conservative density from existing LPM mapping: 9-bit1024deep;
        # map10..18bits512deep, then measure the one selected fit.
        map_depth=1024 if bits<=9 else 512 if bits<=18 else 256
        alternatives.append(dict(tile_size=size,unique_tiles=unique,payload_words=len(dictionary),
            map_words=len(tilemap),map_bits=bits,
            estimated_m10k=math.ceil(len(dictionary)/1024)+math.ceil(len(tilemap)/map_depth)+1))
    analysis=dict(raw_two_panels_estimated_m10k=244,alternatives=alternatives,
        colors={s:len(set(c)) for s,(c,m) in full.items()},
        empty_wells={s:[largest_black_rect(c,r) for r in [(175,250,240,294),(175,294,240,336),(175,336,240,376),(140,185,240,224)]]
                     for s,(c,m) in full.items()})
    if args.inspect:print(json.dumps(analysis,indent=2))
    dictionary,tilemap,unique=tiled(full,2)
    assert (len(dictionary),len(tilemap),unique)==(69628,62208,17407)
    if args.install:
        MIFS.mkdir(parents=True,exist_ok=True)
        write_mif(MIFS/'results_tilemap.mif',15,tilemap)
        write_mif(MIFS/'results_tiles_rgba9.mif',9,dictionary)
    if args.preview or args.audit or args.build_results:
        assert parse_mif((MIFS/'results_tilemap.mif').read_text())==(15,62208,tilemap)
        assert parse_mif((MIFS/'results_tiles_rgba9.mif').read_text())==(9,69628,dictionary)
    if args.audit:
        manifest=json.loads((ROOT/'db/results_build/source_manifest.json').read_text(encoding='utf-8-sig'))
        hardware={n:h for n,h in manifest.items() if Path(n).suffix.lower() in
                  {'.sv','.svh','.v','.bdf','.mif','.qsf','.qpf','.qip','.sdc','.tcl','.qxp','.stp','.hex'} and
                  n not in {'RTL/VGA/results_report_renderer.svh','simulation/results_reports_tb.sv'}}
        for name,digest in hardware.items():
            assert sha((ROOT/name).read_bytes()).upper()==digest.upper(),'Protected input changed: '+name
        old=(ROOT/'db/results_v3_baseline/results_report_renderer.svh').read_text()
        current=(ROOT/'RTL/VGA/results_report_renderer.svh').read_text()
        snap=lambda text:text[text.index('    localparam logic'):text.index('    logic panelHit')]
        assert snap(old)==snap(current),'Terminal snapshot sequencing changed'
        print(f'PRESERVATION_PASS:{len(hardware)} hardware/configuration inputs byte-identical; statistics snapshot unchanged')
    if args.preview:
        OUT.mkdir(parents=True,exist_ok=True);FIX.mkdir(parents=True,exist_ok=True)
        (OUT/'memory_analysis.json').write_text(json.dumps(analysis,indent=2)+'\n')
        _,_,font=parse_mif((ROOT/'RTL/mifs/numbers_new_font.mif').read_text())
        _,_,hud=parse_mif((ROOT/'RTL/mifs/hud_frame_rgb332.mif').read_text())
        scene=arena_scene();offset=0
        for _,x,y,w,h in REGIONS:
            patch=Image.new('RGB',(w,h));patch.putdata([rgb(v) for v in hud[offset:offset+w*h]])
            scene.paste(patch,(x,y));offset+=w*h
        proof={}
        for si,state in enumerate(['victory','defeat']):
            colors,masks=full[state]
            reconstructed=[]
            for y in range(432):
                for x in range(288):
                    index=tilemap[si*31104+(y//2)*144+x//2]
                    reconstructed.append(dictionary[index*4+(y%2)*2+x%2])
            assert reconstructed==[(m<<8)|v for v,m in zip(colors,masks)],'Lossless active ROM reconstruction failed'
            proof[state]=dict(rgb_mismatch_pixels=0,alpha_mismatch_pixels=0,
                rgba_words_sha256=sha(bytes(v for word in reconstructed for v in [word&255,word>>8])))
            # Independent fixtures come directly from full authoritative MIFs,
            # never from the dictionary/tile map used by the production RTL.
            (FIX/(state+'_rgba.hex')).write_text(''.join(f'{(m<<8)|v:03x}\n' for v,m in zip(colors,masks)))
            raw=Image.new('RGBA',(288,432));raw.putdata([(*rgb(v),255*m) for v,m in zip(colors,masks)])
            approved=Image.open(SOURCE/'source/approved_vga_panels'/(state+'_full_288x432_RGB332_RGBA.png')).convert('RGBA')
            assert raw.tobytes()==approved.tobytes(),'Active-ROM PNG is not byte-exact approved RGBA'
            proof[state]['approved_png_rgba_equal']=True
            raw.save(OUT/(state+'_active_rom_panel_288x432.png'))
            for case in ['blank','sample','zero','max']:
                values=['92','089','001','000'] if state=='victory' else ['67','034','016','003']
                if case=='zero':values=['00','000','000','000']
                if case=='max':values=['99','999','999','999']
                result=numbers(scene,font,[values[0],'92']+values[1:])
                under=result.copy();result.paste(raw,(248,24),raw)
                fields=FIELDS[state];texts=values[1:] if state=='victory' else values
                for (x,y,count,ink),text in zip(fields,texts):
                    # Preserve every supplied static pixel; use only empty opaque wells.
                    assert len(text)==count
                    for yy in range(y,y+14):
                        for xx in range(x,x+12*count):
                            idx=(yy-24)*288+xx-248
                            assert colors[idx]==0 and masks[idx]==1,'Number does not fit its approved well'
                    if case=='blank':continue
                    for n,digit in enumerate(text):
                        for dy,fy in enumerate(FONT_Y):
                            for dx,fx in enumerate(FONT_X):
                                if font[int(digit)*512+fy*16+fx]:result.putpixel((x+n*12+dx,y+dy),rgb(ink))
                # Outside panel AND transparent panel corners remain the current scene.
                for yy in range(480):
                    for xx in range(640):
                        if not(248<=xx<536 and 24<=yy<456):
                            assert result.getpixel((xx,yy))==under.getpixel((xx,yy))
                        elif not masks[(yy-24)*288+xx-248]:
                            assert result.getpixel((xx,yy))==under.getpixel((xx,yy))
                result.save(OUT/(state+'_'+case+'_640x480.png'))
                if case=='sample':result.resize((1280,960),Image.Resampling.NEAREST).save(OUT/(state+'_2x.png'))
        (FIX/'font.hex').write_text(''.join(f'{v:x}\n' for v in font))
        previous=subprocess.check_output(['git','show','ddde7c3:RTL/VGA/End_Message_Display.sv'],cwd=ROOT)
        (FIX/'previous_end_message_display.sv').write_bytes(previous.replace(
            b'module end_message_display (',b'module previous_end_message_display (',1))
        (OUT/'verification.json').write_text(json.dumps(dict(
            archive_sha256=sha(ARCHIVE.read_bytes()) if ARCHIVE.exists() else None,
            supplied_files_sha256={p.relative_to(SOURCE).as_posix():sha(p.read_bytes()) for p in SOURCE.rglob('*') if p.is_file()},
            panel_bounds=[248,24,536,456],tile_size=2,unique_tiles=unique,
            payload_words=len(dictionary),map_words=len(tilemap),proof=proof,
            fields=FIELDS,font_x=FONT_X,font_y=FONT_Y,
            full_references_exact=True,lossy_shared_lower_rejected=True,
            scene_unchanged_outside_alpha=True,hardware_tested=False),indent=2)+'\n')
    if args.build_results:
        manifest=json.loads((args.build_results.parents[1]/'source_manifest.json').read_text(encoding='utf-8-sig'))
        inputs={n:h for n,h in manifest.items() if Path(n).suffix.lower() in
                {'.sv','.svh','.v','.bdf','.mif','.qsf','.qpf','.qip','.sdc','.tcl','.qxp','.stp','.hex'}}
        for name,digest in inputs.items():assert sha((ROOT/name).read_bytes()).upper()==digest.upper(),name
        current=inspect_build(args.build_results)
        previous=inspect_build(ROOT/'db/results_build/source/output_files')
        rows=[line for line in (args.build_results/'Lab1Demo.fit.rpt').read_text().splitlines()
              if 'ALTSYNCRAM' in line and 'M10K_X' in line]
        report_rows=[r for r in rows if 'results_report_renderer:results' in r]
        blocks=lambda rs:len(set(re.findall(r'M10K_X\d+_Y\d+_N\d+','\n'.join(rs))))
        assert all('RTL/mifs/results/' not in r for r in report_rows),'Obsolete result ROM still allocated'
        measured=dict(baseline=previous,current=current,total_m10k=blocks(rows),
            results_m10k=blocks(report_rows),compiled_inputs_verified=len(inputs))
        (OUT/'quartus_results.json').write_text(json.dumps(measured,indent=2)+'\n')
        print(json.dumps(measured,indent=2))
    print('RESULTS_V3_ASSETS_PASS: authoritative full panels; exact RGB332/binary alpha; no artwork generation')


if __name__=='__main__':main()
