"""Exact approved Phase3B.2 artwork conversion/verification, never art generation.

--install writes ONLY the packed boundary MIF from approved empty-window PNG.
--fixtures decodes independent full-screen/font expectations for ModelSim.
--preview renders actual active MIFs and asserts exact approved-scene equality.
--build-results reads one completed Quartus build against the previous HUD build.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from PIL import Image

sys.dont_write_bytecode = True
from build_jungle_assets import parse_mif, rgb
from supplied_floor_tiles import load
from implement_v4_graphics import floor_map, NAMES

ROOT = Path(__file__).resolve().parents[1]
APPROVED = ROOT/'assets/jungle/hud_layout_fix_preview'
OUT = ROOT/'assets/jungle/hud_final_implemented'
MIF = ROOT/'RTL/mifs/hud_frame_rgb332.mif'
SHAS = {
    'empty_counter_windows_640x480.png': '4fa2ed6002a50e30fe460e47dd1fe7b8802c75e4d36d8c83f8d31a1a533542dd',
    'full_scene_640x480.png': '0e65c4e3bdbef5ba07846cd1334616cb42268fd73f22ba4ccb0430de86124a05',
    'full_scene_2x.png': 'bd2cfcce58247911d443aff8b4c14ef50f818b470fed4010011394f4d28744d7',
}
FIELDS = [('score',57,116,2,0xF9),('high_score',56,182,2,0xF9),
          ('ruby',64,273,3,0xED),('sapphire',64,317,3,0x57),('cursed',64,362,3,0xB3)]
WINDOWS = [(35,108,76,32),(33,175,78,32),(59,268,59,27),(59,313,59,27),(59,358,59,27)]
REGIONS = [('left',0,0,144,480),('top',144,0,496,24),
           ('bottom',144,456,496,24),('right',624,24,16,432)]
PALETTE = {rgb(v):v for v in range(256)}


def inspect_build(folder):
    result = {'stages':{}}
    for stage in ['map','fit','sta','asm']:
        text=(folder/f'Lab1Demo.{stage}.rpt').read_text()
        totals=re.search(r'was successful\.\s*(\d+) errors,\s*(\d+) warnings',text)
        assert totals and int(totals[1])==0, f'Incomplete/failed {stage}'
        result['stages'][stage]=dict(errors=int(totals[1]),warnings=int(totals[2]),
            codes=dict(Counter(re.findall(r'^\s*(?:Critical )?Warning \((\d+)\):',text,re.M))))
    text=(folder/'Lab1Demo.sta.summary').read_text()
    timing=re.findall(r"Type\s*:\s*(.+?)\s+'([^']+)'\s*\nSlack\s*:\s*([-+\d.]+)\s*\nTNS\s*:\s*([-+\d.]+)",text)
    assert timing and all(float(s)>0 and float(t)==0 for _,_,s,t in timing), 'Nonpositive timing margin'
    for corner in ['Slow 1100mV 85C','Slow 1100mV 0C','Fast 1100mV 85C','Fast 1100mV 0C']:
        for kind in ['Setup','Hold']:
            assert any(c==corner+' Model '+kind and k.endswith('|divclk') for c,k,_,_ in timing)
    result['timing']=[dict(check=c,clock=k,slack=float(s),tns=float(t)) for c,k,s,t in timing]
    result['worst_setup']=min(float(s) for c,_,s,_ in timing if c.endswith('Setup'))
    result['worst_hold']=min(float(s) for c,_,s,_ in timing if c.endswith('Hold'))
    result['resources']=dict(re.findall(r'^(Logic utilization \(in ALMs\)|Total registers|Total pins|Total block memory bits|Total RAM Blocks|Total DSP Blocks|Total PLLs)\s*:\s*(.+)$',
        (folder/'Lab1Demo.fit.summary').read_text(),re.M))
    assert len(result['resources'])==7
    return result


def arena_scene():
    old=json.loads((ROOT/'assets/jungle/implemented/arena_map.json').read_text())
    blocked={tuple(p) for p in old['blocked']}
    floor=floor_map(blocked)
    descriptors=[d if d&7>=4 else floor[i] for i,d in enumerate(old['descriptor'])]
    assert len(blocked)==30
    scene=Image.new('RGB',(640,480),rgb(4))
    tiles=[load(n)[1] for n in NAMES]
    rotations=[None,Image.Transpose.ROTATE_270,Image.Transpose.ROTATE_180,Image.Transpose.ROTATE_90]
    for i,d in enumerate(descriptors):
        tile=tiles[d&7]
        if d>>3: tile=tile.transpose(rotations[d>>3])
        scene.paste(tile,(144+i%20*24,24+i//20*24),tile)
    pose=[(10,10),(10,11),(10,12),(10,13),(10,14),(11,14),(12,14),(13,14),
          (13,13),(13,12),(13,11),(13,10),(13,9),(13,8),(13,7),(13,6)]
    for name,x,y in [('snake_body_24',x,y) for x,y in pose]+[
        ('snake_head_24',10,9),('red_apple_24',7,3),('blue_apple_24',5,10),('black_apple_24',12,6)]:
        _,sprite=load(name)
        scene.paste(sprite,(144+x*24,24+y*24),sprite)
    return scene


def numbers(scene,font,values):
    result=scene.copy()
    for (name,x,y,digits,col),value in zip(FIELDS,values):
        assert len(value)==digits
        for i,letter in enumerate(value):
            for dy in range(18):
                for dx in range(16):
                    if font[int(letter,16)*512+(6+dy)*16+dx]:
                        result.putpixel((x+i*16+dx,y+dy),rgb(col))
    return result


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--install',action='store_true')
    p.add_argument('--fixtures',action='store_true')
    p.add_argument('--preview',action='store_true')
    p.add_argument('--git-index',action='store_true')
    p.add_argument('--build-results',type=Path)
    args=p.parse_args()
    for name,expected in SHAS.items():
        assert hashlib.sha256((APPROVED/name).read_bytes()).hexdigest()==expected, 'Approved input changed: '+name
    empty=Image.open(APPROVED/'empty_counter_windows_640x480.png').convert('RGB')
    approved=Image.open(APPROVED/'full_scene_640x480.png').convert('RGB')
    large=Image.open(APPROVED/'full_scene_2x.png').convert('RGB')
    assert empty.size==approved.size==(640,480) and large.size==(1280,960)
    assert large.tobytes()==approved.resize((1280,960),Image.Resampling.NEAREST).tobytes()
    # No approximation, dithering or recoloring: reject any non-RGB332 source pixel.
    raster=[PALETTE[pixel] for pixel in empty.get_flattened_data()]
    atlas=[]; offsets={}; coverage=set()
    for name,x,y,w,h in REGIONS:
        offsets[name]=len(atlas)
        for yy in range(y,y+h):
            for xx in range(x,x+w):
                assert not(144<=xx<624 and 24<=yy<456)
                address=yy*640+xx
                assert address not in coverage
                coverage.add(address); atlas.append(raster[address])
    assert offsets==dict(left=0,top=69120,bottom=81024,right=92928) and len(atlas)==99840
    if args.install:
        MIF.write_text('WIDTH=8;\nDEPTH=99840;\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n'+
            ''.join(f'{i} : {v:02X};\n' for i,v in enumerate(atlas))+'END;\n',encoding='ascii')
    width,depth,active=parse_mif(MIF.read_text())
    assert (width,depth,active)==(8,99840,atlas), 'Active boundary ROM differs from approved pixels'
    if args.git_index:
        staged=subprocess.check_output(['git','show',':RTL/mifs/hud_frame_rgb332.mif'],cwd=ROOT)
        assert staged==MIF.read_bytes(), 'Staged boundary MIF bytes differ from verified asset'
    _,_,font=parse_mif((ROOT/'RTL/mifs/numbers_new_font.mif').read_text())
    assert hashlib.sha256((ROOT/'RTL/mifs/numbers_new_font.mif').read_bytes()).hexdigest()==(
        '4c06cdff1a35ff2908db2635b4b946ac10f2b52d41f151bb6554e9552ea8b58d')
    layout=(ROOT/'RTL/VGA/jungle_hud_layout.svh').read_text()
    params={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',layout)}
    assert [params[k] for k in ['HUD_LEFT','HUD_TOP','HUD_RIGHT','HUD_BOTTOM','SCORE_X','SCORE_Y',
        'HIGH_SCORE_X','HIGH_SCORE_Y','RELIC_X','RUBY_Y','SAPPHIRE_Y','CURSED_Y','HUD_DIGIT_WIDTH','HUD_DIGIT_HEIGHT']]==[
        8,8,136,472,57,116,56,182,64,273,317,362,16,18]
    for (name,x,y,digits,_),(l,t,w,h) in zip(FIELDS,WINDOWS):
        assert l<=x and x+digits*16<=l+w and t<=y and y+18<=t+h, name
        assert all(raster[yy*640+xx]==0 for yy in range(y,y+18) for xx in range(x,x+digits*16)), 'Numerical window is not empty'
    scene=arena_scene()
    assert scene.crop((144,24,624,456)).tobytes()==approved.crop((144,24,624,456)).tobytes()
    for name,x,y,w,h in REGIONS:
        region=Image.new('RGB',(w,h))
        region.putdata([rgb(v) for v in active[offsets[name]:offsets[name]+w*h]])
        scene.paste(region,(x,y))
    assert scene.tobytes()==empty.tobytes(), 'Actual-MIF empty scene differs from approved design'
    full=numbers(scene,font,['12','19','012','345','678'])
    assert full.tobytes()==approved.tobytes(), 'Actual-MIF live scene differs from approved design'
    if args.fixtures:
        fixtures=ROOT/'db/jungle_hud_final_fixture';fixtures.mkdir(parents=True,exist_ok=True)
        # Expectations come directly from the approved screen raster, NOT atlas indexing.
        (fixtures/'screen.hex').write_text(''.join(f'{v:02x}\n' for v in raster))
        (fixtures/'font.hex').write_text(''.join(f'{v:x}\n' for v in font))
    if args.preview:
        OUT.mkdir(parents=True,exist_ok=True)
        scene.save(OUT/'empty_counter_windows_640x480.png')
        full.save(OUT/'full_scene_640x480.png')
        full.resize((1280,960),Image.Resampling.NEAREST).save(OUT/'full_scene_2x.png')
        numbers(scene,font,['00','00','000','000','000']).save(OUT/'zero_values_640x480.png')
        numbers(scene,font,['99','99','999','999','999']).save(OUT/'max_decimal_values_640x480.png')
        (OUT/'verification.json').write_text(json.dumps(dict(
            approved_inputs=SHAS,atlas_pixels=99840,atlas_logical_bits=798720,atlas_offsets=offsets,
            atlas_mif_sha256=hashlib.sha256(MIF.read_bytes()).hexdigest(),
            approved_scene_pixel_identical=True,arena_pixels_unchanged=207360,fields=FIELDS,
            digit_size=[16,18],opaque_black_pixels=atlas.count(0),opaque_white_pixels=atlas.count(255),
            geometry_drawing_mask=True,no_gameplay_geometry_changes=True),indent=2)+'\n')
    if args.build_results:
        result=dict(baseline_97c1782=inspect_build(ROOT/'db/phase3b_build/source/output_files'),
                    final_hud=inspect_build(args.build_results))
        print(json.dumps(result,indent=2))
    print('FINAL_HUD_ASSETS_PASS: 99840 exact boundary pixels; independent geometry mask; full16x18 digits; actual-MIF scene equals approved preview; arena unchanged')


if __name__=='__main__':
    main()
