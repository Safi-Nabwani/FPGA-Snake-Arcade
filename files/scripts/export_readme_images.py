"""Export lossless 3x PNGs from actual production RTL/MIF compositor frames.

Run from anywhere with Pillow and ModelSim installed. No production inputs are written.
The testbench uses deterministic collection/collision test stimuli, not a recorded playthrough.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
sys.dont_write_bytecode = True
from PIL import Image
from rom_assets import parse_mif, rgb, numbers

FILES = Path(__file__).resolve().parents[1]
ROOT = FILES.parent
DUMPS = FILES/'db/readme_images'
NAMES = ('opening','gameplay','victory','defeat')
PALETTE = [component for i in range(256) for component in rgb(i)]

def indexed(data,size):
    image=Image.frombytes('P',size,data)
    image.putpalette(PALETTE)
    return image

def codes(image):
    # Match the approved project's RGB332 importer. PNG reference channels can
    # differ by one level from its floor-expanded preview palette, without any
    # difference in the authoritative eight-bit ROM pixels.
    return bytes((round(r*7/255)<<5)|(round(g*7/255)<<2)|round(b*3/255) for r,g,b in image.convert('RGB').get_flattened_data())

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reuse-dumps',action='store_true',help='Use completed dumps from this exact testbench version')
    parser.add_argument('--vsim',default=shutil.which('vsim') or 'C:/intelFPGA_lite/17.0/modelsim_ase/win32aloem/vsim.exe')
    args=parser.parse_args()
    manifest=json.loads((FILES/'verification/source_sha256.json').read_text())
    def protected_inputs():
        for name,digest in manifest.items():
            assert hashlib.sha256((FILES/name).read_bytes()).hexdigest()==digest,name
        assert hashlib.sha256((ROOT/'TheTemplesCurse.sof').read_bytes()).hexdigest().upper()==json.loads(
            (FILES/'verification/release_results.json').read_text(encoding='utf-8-sig'))['sof_sha256']
    protected_inputs()
    DUMPS.mkdir(parents=True,exist_ok=True)
    if not args.reuse_dumps:
        with (DUMPS/'simulation.log').open('wb') as log:
            result=subprocess.run([args.vsim,'-c','-do','simulation/readme_images.do'],cwd=FILES,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError((DUMPS/'simulation.log').read_text(errors='replace')[-4000:])
    log=(DUMPS/'simulation.log').read_text(errors='replace')
    assert 'README_IMAGES_PASS' in log,'Incomplete capture'
    states={m[0]:dict(score=m[1],high=m[2],ruby=m[3],sapphire=m[4],cursed=m[5]) for m in re.findall(
        r'FRAME_CAPTURE (\w+) score=(\d{2}) high=(\d{2}) counts=(\d{3})/(\d{3})/(\d{3})',log)}
    assert set(states)==set(NAMES)
    def rom(name):return parse_mif((FILES/'RTL/mifs'/name).read_text())[2]
    hud,font=rom('hud_frame_rgb332.mif'),rom('numbers_new_font.mif')
    tilemap,payload=rom('results_v3/results_tilemap.mif'),rom('results_v3/results_tiles_rgba9.mif')
    native={}
    for name in NAMES:
        path=DUMPS/(name+'.rgb332')
        assert path.stat().st_mtime >= (FILES/'simulation/readme_images_tb.sv').stat().st_mtime,'Stale capture'
        data=path.read_bytes();assert len(data)==640*480
        native[name]=indexed(data,(640,480)).convert('RGB')
        scene=Image.new('RGB',(640,480))
        scene.paste(indexed(bytes(hud[:69120]),(144,480)),(0,0))
        values=[states[name][field] for field in ('score','high','ruby','sapphire','cursed')]
        expected=numbers(scene,font,values)
        assert native[name].crop((0,0,144,480)).tobytes()==expected.crop((0,0,144,480)).tobytes(),f'{name}: HUD/pipeline mismatch'
    approved=Image.open(FILES/'assets/jungle/approved_opening/opening_640x480_preview.png').convert('RGB')
    assert (DUMPS/'opening.rgb332').read_bytes()==codes(approved),'Opening differs from the approved RGB332 full-scene pixels'
    # Independent active-ROM check of report pixels and all live digits.
    fields={
        'victory':[(438,290,'ruby',0xED),(437,331,'sapphire',0x57),(437,371,'cursed',0xB3)],
        'defeat':[(443,230,'score',0xF9),(431,286,'ruby',0xED),(431,324,'sapphire',0x57),(431,363,'cursed',0xB3)]}
    fx=[0,2,3,4,6,7,8,10,11,12,14,15];fy=[6,7,9,10,11,13,14,15,16,18,19,20,22,23]
    for state_index,name in enumerate(('victory','defeat')):
        ink={}
        for x,y,field,color in fields[name]:
            for n,digit in enumerate(states[name][field]):
                for yy in range(14):
                    for xx in range(12):
                        if font[int(digit)*512+fy[yy]*16+fx[xx]]:ink[x+n*12+xx,y+yy]=rgb(color)
        for y in range(432):
            for x in range(288):
                word=payload[4*tilemap[state_index*31104+(y//2)*144+x//2]+(y%2)*2+x%2]
                target=(248+x,24+y)
                if target in ink:assert native[name].getpixel(target)==ink[target],(name,target,'digit')
                elif word>>8:assert native[name].getpixel(target)==rgb(word&255),(name,target,'ROM')
    out=ROOT/'images';out.mkdir(exist_ok=True)
    for name in NAMES:
        enlarged=native[name].resize((1920,1440),Image.Resampling.NEAREST)
        # Exact RGB332 palette indexing: no quantization, recoloring, antialiasing or loss.
        packed=indexed(codes(enlarged),enlarged.size)
        assert packed.convert('RGB').tobytes()==enlarged.tobytes()
        path=out/(name+'.png');packed.save(path,optimize=True,compress_level=9)
        decoded=Image.open(path).convert('RGB')
        assert decoded.tobytes()==enlarged.tobytes()
        assert decoded.resize((640,480),Image.Resampling.NEAREST).tobytes()==native[name].tobytes()
        print(json.dumps(dict(image='images/'+name+'.png',width=1920,height=1440,bytes=path.stat().st_size,state=states[name])))
    protected_inputs()
    print('README_IMAGES_VERIFIED: active RTL compositor; exact approved opening; HUD and report data/pipeline checked; lossless 3x; protected inputs/SOF unchanged')

if __name__=='__main__':main()
