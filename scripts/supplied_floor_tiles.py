"""Exact supplied MIF verification, deterministic floor map, fixtures and preview.

No image generation, palette conversion, or active MIF/header writes.
--header prints the source table for installation with the normal patch tool.
--fixtures writes ignored simulation fixtures. --preview decodes MIFs only.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import random
import re
import subprocess
import sys
import zipfile
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
from build_jungle_assets import parse_mif, rgb
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/jungle/supplied_floor_tiles'
NAMES = ['ancient_stone','mossy_stone','cracked_stone','engraved_stone']
STEMS = [n+'_24x24_rgb332' for n in NAMES]
SEED = 20261011
EXPECTED_SHA256 = {
    'ancient_stone': '71d4e8e6e5a65e10a79dacf3fa7c145a9ee47e3911011858cb3a6c26366e0fba',
    'mossy_stone': 'b6089d1f9ffaddc0b81d70675c380a4601bbe9dfc3f606cd6657bae696cb6f6a',
    'cracked_stone': '99726b152b574bce694418058b13eec470567b47e7212796c7b6b8fbcd0d3b90',
    'engraved_stone': '676342b7a54a35f6b341f8692db1da2062cda16c90127284d34b20b93ff73501',
}

def penalty(g):
    total = 0
    for y in range(18):
        for x in range(20):
            v = g[y*20+x]
            if x<17 and all(g[y*20+x+k]==v for k in range(4)): total+=5
            if y<15 and all(g[(y+k)*20+x]==v for k in range(4)): total+=5
            if x<19 and y<17 and v==g[y*20+x+1]==g[(y+1)*20+x]==g[(y+1)*20+x+1]: total+=5
            if x<15 and g[y*20+x:y*20+x+6]==[v,g[y*20+x+1]]*3: total+=2
            if y<13 and [g[(y+k)*20+x] for k in range(6)]==[v,g[(y+1)*20+x]]*3: total+=2
    return total

def floor_map(blocked):
    rng=random.Random(SEED); g=[None]*360
    visible=[i for i in range(360) if (i%20,i//20) not in blocked]
    hidden=[i for i in range(360) if i not in visible]
    for indices,counts in [(visible,[149,82,66,33]),(hidden,[13,8,6,3])]:
        values=[v for v,n in enumerate(counts) for _ in range(n)]; rng.shuffle(values)
        for i,v in zip(indices,values): g[i]=v
    score=penalty(g)
    for _ in range(20000):
        if not score: break
        a,b=rng.sample(visible if rng.random()<.9 else hidden,2)
        if g[a]==g[b]: continue
        g[a],g[b]=g[b],g[a]; trial=penalty(g)
        if trial<=score: score=trial
        else: g[a],g[b]=g[b],g[a]
    assert score==0 and collections.Counter(g)=={0:162,1:90,2:72,3:36}
    assert len({tuple(g[y*20:y*20+20]) for y in range(18)})==18
    assert len({tuple(g[y*20+x] for y in range(18)) for x in range(20)})==20
    assert g!=list(reversed(g))
    return g

def header(g):
    lines=['// Supplied approved floor selection only; obstacles remain in jungle_map.svh.',
           '// Generated map: seed 20261011; 162/90/72/36 cells. No floor artwork rotation.',
           'function automatic [1:0] jungleFloorTile(input logic [4:0] x, y);',
           '    logic [39:0] row;', '    begin', '        case (y)']
    for y in range(18):
        row=sum(g[y*20+x]<<(2*x) for x in range(20))
        lines.append(f"        5'd{y}: row = 40'h{row:010X};")
    lines += ["        default: row = 40'd0;",'        endcase',
              "        jungleFloorTile = (x < 20 && y < 18) ? ((row >> (x * 2)) & 40'h3) : 2'd0;",
              '    end', 'endfunction', '']
    return '\n'.join(lines)

def load(name):
    width,depth,codes=parse_mif((ROOT/'RTL/mifs'/f'{name}.mif').read_text())
    assert (width,depth)==(8,576)
    im=Image.new('RGBA',(24,24)); im.putdata([(*rgb(v),0 if v==255 else 255) for v in codes])
    return codes,im

def hud(scene):
    d=ImageDraw.Draw(scene); d.rectangle((8,24,127,455),fill=rgb(4))
    for r in [(8,24,9,455),(126,24,127,455),(8,24,127,25),(8,454,127,455),(8,100,127,100),(8,192,127,192)]: d.rectangle(r,fill=rgb(0x8D))
    text=(ROOT/'RTL/VGA/hud_labels.sv').read_text()
    glyphs={c:b.replace('_','') for c,b in re.findall(r'"(.)": glyph = 35\x27b([01_]+)',text)}
    for label,oy,col in [('SCORE',40,0xF9),('HIGH',112,0xF9),('SCORE',128,0xF9),('RELICS',208,0xF9),('RUBY',240,0xED),('SAPPHIRE',308,0x57),('CURSED',376,0xB3)]:
        for i,c in enumerate(label):
            for bit,on in enumerate(glyphs[c]):
                if on=='1':
                    x,y=16+i*12+(bit%5)*2,oy+(bit//5)*2
                    d.rectangle((x,y,x+1,y+1),fill=rgb(col))
    _,_,font=parse_mif((ROOT/'RTL/mifs/numbers_new_font.mif').read_text())
    for value,ox,oy,col in [('12',48,64,0xD9),('19',48,148,0xF9),('012',40,260,0xED),('000',40,328,0x57),('000',40,396,0xB3)]:
        for i,c in enumerate(value):
            for y in range(32):
                for x in range(16):
                    if font[int(c)*512+y*16+x]: scene.putpixel((ox+i*16+x,oy+y),rgb(col))

def main():
    p=argparse.ArgumentParser(); p.add_argument('--archive',type=Path);p.add_argument('--header',action='store_true');p.add_argument('--fixtures',action='store_true');p.add_argument('--preview',action='store_true');p.add_argument('--git-index',action='store_true');a=p.parse_args()
    old=json.loads((ROOT/'assets/jungle/implemented/arena_map.json').read_text())
    blocked={tuple(c) for c in old['blocked']};assert len(blocked)==30
    g=floor_map(blocked)
    if a.header: print(header(g)); return
    assert (ROOT/'RTL/VGA/jungle_floor_map.svh').read_text()==header(g)
    records={}
    for stem in STEMS:
        path=ROOT/'RTL/mifs'/f'{stem}.mif';raw=path.read_bytes();codes,im=load(stem)
        assert hashlib.sha256(raw).hexdigest()==EXPECTED_SHA256[stem.removesuffix('_24x24_rgb332')]
        assert 255 not in codes, 'Unexpected floor transparency: stop, never alter supplied art'
        preview=Image.open(OUT/f'{stem}.png').convert('RGB')
        assert preview.size==(24,24)
        # Author PNG may round channel expansion; MIF values remain authoritative.
        assert max(abs(c-d) for px,py in zip(preview.get_flattened_data(),im.convert('RGB').get_flattened_data()) for c,d in zip(px,py))<=1
        if a.archive:
            with zipfile.ZipFile(a.archive) as z: assert raw==z.read(stem+'.mif')
        if a.git_index:
            assert raw==subprocess.check_output(['git','show',':RTL/mifs/'+stem+'.mif'],cwd=ROOT)
        records[stem]={'sha256':hashlib.sha256(raw).hexdigest(),'words':len(codes),'colors':len(set(codes))}
    merged=[old['descriptor'][i] if (old['descriptor'][i]&7)>=4 else g[i] for i in range(360)]
    for i,d in enumerate(old['descriptor']):
        if (d&7)>=4: assert merged[i]==d
    if a.fixtures:
        subprocess.run([sys.executable,str(ROOT/'scripts/implement_jungle_preview.py'),'--fixtures'],cwd=ROOT,check=True)
        fixture=ROOT/'db/jungle_implementation_fixture'
        for stem in STEMS:
            codes,_=load(stem);(fixture/f'{stem}.hex').write_text(''.join(f'{v:02x}\n' for v in codes))
        (fixture/'map.hex').write_text(''.join(f'{v:02x}\n' for v in merged))
    if a.preview:
        scene=Image.new('RGB',(640,480),rgb(4));hud(scene)
        names=STEMS+['rock_tile_24','ruin_wall_24','ruin_pillar_24'];tiles=[load(n)[1] for n in names]
        rot=[None,Image.Transpose.ROTATE_270,Image.Transpose.ROTATE_180,Image.Transpose.ROTATE_90]
        for i,desc in enumerate(merged):
            tile=tiles[desc&7]
            if desc>>3:tile=tile.transpose(rot[desc>>3])
            x,y=144+(i%20)*24,24+(i//20)*24;scene.paste(tile,(x,y),tile)
            assert scene.crop((x,y,x+24,y+24)).tobytes()==tile.convert('RGB').tobytes()
        pose=[(10,10),(10,11),(10,12),(10,13),(10,14),(11,14),(12,14),(13,14),(13,13),(13,12),(13,11),(13,10),(13,9),(13,8),(13,7),(13,6)]
        objects=[('snake_body_24',x,y) for x,y in pose]+[('snake_head_24',10,9),('red_apple_24',7,3),('blue_apple_24',5,10),('black_apple_24',12,6)]
        for name,x,y in objects:
            assert (x,y) not in blocked;_,im=load(name);scene.paste(im,(144+x*24,24+y*24),im)
        scene.save(OUT/'full_scene_640x480.png')
        (OUT/'floor_selection_map.json').write_text(json.dumps({'seed':SEED,'rows':18,'columns':20,'variants':g,'counts':[162,90,72,36],'visible_counts':[149,82,66,33],'blocked':old['blocked']},indent=2)+'\n')
        (OUT/'asset_verification.json').write_text(json.dumps(records,indent=2)+'\n')
    print('SUPPLIED_FLOOR_PASS: exact archive MIF bytes, RGB332 PNG agreement, 360-cell 45/25/20/10 map, unchanged 30 obstacles, no floor rotation')

if __name__=='__main__':main()
