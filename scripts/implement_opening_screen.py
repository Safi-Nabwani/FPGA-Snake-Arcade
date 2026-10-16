"""Mechanical approved-PNG -> native RGB332 conversion; no artwork generation.

Only the authorized tutorial text is corrected, using the existing 5x7 font
with a few missing characters. --install explicitly writes the new menu MIF.
Without it, active assets are read-only. Preview is decoded from that actual MIF.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from PIL import Image

sys.dont_write_bytecode = True
from build_jungle_assets import parse_mif, rgb
from implement_final_hud import inspect_build

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/jungle/opening_screen'
SOURCE = OUT/'source_approved.png'
MIF = ROOT/'RTL/mifs/opening_screen_rgb332.mif'
SOURCE_SHA = 'e69f3adf21123ecf046384719233df1d2bead9f5cb54c3fce6d35c3156469cf3'
TEXT = [
    (381,256,'+1 SCORE'), (381,267,'+1 LENGTH'),
    (381,298,'+3 SCORE'), (381,309,'-3 LENGTH'),
    (381,339,'-5 SCORE'), (381,350,'+5 LENGTH'),
    (193,345,'NUMPAD 8/4/6/2'),
]
BOXES = [(379,255,466,276),(379,295,466,319),(379,336,466,358)]


def expected():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_SHA
    source=Image.open(SOURCE).convert('RGB')
    assert source.size==(1448,1086) and 1448*480==1086*640
    native=source.resize((640,480),Image.Resampling.NEAREST)
    codes=[(round(r*7/255)<<5)|(round(g*7/255)<<2)|round(b*3/255)
           for r,g,b in native.get_flattened_data()]
    # Reuse the project's pixel font rather than rasterizing a system TTF.
    labels=(ROOT/'RTL/VGA/hud_labels.sv').read_text()
    glyph={k:v.replace('_','') for k,v in re.findall(r'"(.)": glyph = 35\'b([01_]+)',labels)}
    glyph.update({
        'M':'10001_11011_10101_10101_10001_10001_10001',
        'N':'10001_11001_10101_10011_10001_10001_10001',
        'T':'11111_00100_00100_00100_00100_00100_00100',
        '1':'00100_01100_00100_00100_00100_00100_01110',
        '2':'01110_10001_00001_00010_00100_01000_11111',
        '3':'11110_00001_00001_01110_00001_00001_11110',
        '4':'00010_00110_01010_10010_11111_00010_00010',
        '5':'11111_10000_10000_11110_00001_00001_11110',
        '6':'01110_10000_10000_11110_10001_10001_01110',
        '8':'01110_10001_10001_01110_10001_10001_01110',
        '+':'00000_00100_00100_11111_00100_00100_00000',
        '-':'00000_00000_00000_11111_00000_00000_00000',
        '/':'00001_00010_00010_00100_01000_01000_10000',
        ' ':'00000_00000_00000_00000_00000_00000_00000',
    })
    glyph={k:v.replace('_','') for k,v in glyph.items()}
    original=list(codes)
    # Only replace text inside its original dark panels, not names, gems or borders.
    # Background is copied from a text-free 4x4 patch of this same approved panel.
    patch=[original[y*640+x] for y in range(247,251) for x in range(453,457)]
    for l,t,r,b in BOXES:
        for y in range(t,b):
            for x in range(l,r): codes[y*640+x]=patch[((y-t)%4)*4+(x-l)%4]
    text_pixels=set()
    for x,y,text in TEXT:
        for i,letter in enumerate(text):
            for row in range(7):
                for col in range(5):
                    if glyph[letter][row*5+col]=='1':
                        p=(y+row)*640+x+i*6+col
                        codes[p]=0xFE;text_pixels.add(p)
    changed={i for i,(a,b) in enumerate(zip(original,codes)) if a!=b}
    allowed={y*640+x for l,t,r,b in BOXES for y in range(t,b) for x in range(l,r)}|text_pixels
    assert changed<=allowed
    return codes,dict(source_sha256=SOURCE_SHA,source_size=[1448,1086],size=[640,480],
        resize='nearest-neighbor, unchanged 4:3 aspect, no crop',rgb_format='RGB332',
        texts=TEXT,text_boxes=BOXES,changed_text_pixels=len(changed),
        source_art_unchanged_outside_authorized_text_regions=True)


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--install',action='store_true')
    p.add_argument('--preview',action='store_true')
    p.add_argument('--fixtures',action='store_true')
    p.add_argument('--draft',action='store_true')
    p.add_argument('--build-results',type=Path)
    p.add_argument('--git-index',action='store_true')
    args=p.parse_args()
    codes,meta=expected()
    if args.install:
        MIF.write_text('WIDTH=8;\nDEPTH=307200;\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n'+
            ''.join(f'{i} : {v:02X};\n' for i,v in enumerate(codes))+'END;\n',encoding='ascii')
    if not args.draft:
        w,d,active=parse_mif(MIF.read_text())
        assert (w,d,active)==(8,307200,codes), 'Active menu MIF differs from deterministic conversion'
        meta['mif_sha256']=hashlib.sha256(MIF.read_bytes()).hexdigest()
        if args.git_index:
            for file in [MIF,SOURCE]:
                blob=subprocess.check_output(['git','show',':'+file.relative_to(ROOT).as_posix()],cwd=ROOT)
                assert blob==file.read_bytes(), 'Staged asset differs: '+str(file)
    else: active=codes
    if args.preview:
        scene=Image.new('RGB',(640,480));scene.putdata([rgb(v) for v in active])
        scene.save(OUT/('draft_640x480.png' if args.draft else 'opening_screen_640x480.png'))
        if not args.draft:
            scene.resize((1280,960),Image.Resampling.NEAREST).save(OUT/'opening_screen_2x.png')
            (OUT/'verification.json').write_text(json.dumps(meta,indent=2)+'\n')
    if args.fixtures:
        fixture=ROOT/'db/opening_screen_fixture';fixture.mkdir(parents=True,exist_ok=True)
        (fixture/'expected.hex').write_text(''.join(f'{v:02X}\n' for v in codes))
        legacy=subprocess.check_output(['git','show','990199e:RTL/VGA/End_Message_Display.sv'],cwd=ROOT)
        (fixture/'legacy_end_message_display.sv').write_bytes(legacy.replace(
            b'module end_message_display (',b'module legacy_end_message_display (',1))
    if args.build_results:
        print(json.dumps(dict(baseline_990199e=inspect_build(ROOT/'db/phase3b2_build/source/output_files'),
                              opening=inspect_build(args.build_results)),indent=2))
    print('OPENING_ASSET_PASS: 640x480 RGB332; all307200 addresses; approved composition; corrected relic effects and keypad label')


if __name__=='__main__': main()
