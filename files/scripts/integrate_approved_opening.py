"""Install/verify the authoritative approved RGB332 binary patches only."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
sys.dont_write_bytecode=True
from PIL import Image
from rom_assets import parse_mif,rgb,numbers

ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'assets/jungle/approved_opening'
MIF=ROOT/'RTL/mifs/opening_supplied_atlas.mif'
def codes(image):
    return bytes((round(r*7/255)<<5)|(round(g*7/255)<<2)|round(b*3/255) for r,g,b in image.convert('RGB').get_flattened_data())

def patched(raw):
    manifest=json.loads((PACK/'manifest.json').read_text())
    width,depth,data=parse_mif(raw.decode())
    assert (width,depth)==(8,104476)
    patches={}
    for name,r in manifest['regions'].items():
        binary=(PACK/r['bin']).read_bytes()
        assert hashlib.sha256(binary).hexdigest()==r['sha256_bin']
        assert hashlib.sha256((PACK/r['png']).read_bytes()).hexdigest()==r['sha256_png']
        assert len(binary)==r['w']*r['h']==r['rom_end_inclusive']-r['rom_start']+1
        png=Image.open(PACK/r['png']).convert('RGB')
        assert png.size==(r['w'],r['h'])
        assert codes(png)==binary
        patches.update({r['rom_start']+i:v for i,v in enumerate(binary)})
    # Surgical decimal-address substitution preserves every other source byte.
    def replace(match):
        address=int(match[1]);return match[0] if address not in patches else match[1]+b' : '+f'{patches[address]:X}'.encode()+b';'
    result=re.sub(rb'(\d+)\s*:\s*[0-9A-Fa-f]+;',replace,raw)
    _,_,new=parse_mif(result.decode())
    assert all(new[i]==patches.get(i,data[i]) for i in range(depth))
    return result,manifest

def main():
    p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');p.add_argument('--preview',action='store_true');args=p.parse_args()
    # The active atlas is authoritative; do not depend on an ignored historical backup.
    raw=MIF.read_bytes()
    expected,manifest=patched(raw)
    if args.install:MIF.write_bytes(expected)
    assert MIF.read_bytes()==expected
    _,_,data=parse_mif(MIF.read_text())
    meta=json.loads((ROOT/'assets/jungle/supplied_opening_implemented/verification.json').read_text())
    def address(x,y):
        for r in meta['regions']:
            if r['x']<=x<r['x']+r['width'] and r['y']<=y<r['y']+r['height']:
                return r['offset']+(y-r['y'])*r['width']+x-r['x']
        return (y//4)*124+x//4
    scene=Image.new('RGB',(640,480));right=Image.new('RGB',(496,480))
    right.putdata([rgb(data[address(x,y)]) for y in range(480) for x in range(496)]);scene.paste(right,(144,0))
    _,_,hud=parse_mif((ROOT/'RTL/mifs/hud_frame_rgb332.mif').read_text())
    _,_,font=parse_mif((ROOT/'RTL/mifs/numbers_new_font.mif').read_text())
    left=Image.new('RGB',(144,480));left.putdata([rgb(v) for v in hud[:69120]]);scene.paste(left,(0,0))
    scene=numbers(scene,font,['00','00','000','000','000'])
    for r in manifest['regions'].values():
        assert codes(scene.crop((r['x'],r['y'],r['x']+r['w'],r['y']+r['h'])))==(PACK/r['bin']).read_bytes()
    assert codes(scene)==codes(Image.open(PACK/'opening_640x480_preview.png'))
    if args.preview:scene.save(PACK/'active_rom_640x480.png')
    print('APPROVED_OPENING_PASS: binaries/PNGs exact; full preview exact; all other ROM words unchanged; 8x104476')
if __name__=='__main__':main()
