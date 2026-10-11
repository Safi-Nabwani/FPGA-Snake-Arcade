"""Exact approved panel integration; derive only its binary alpha, not artwork.

--mask writes the new 1-bit drawing mask from the supplied RGB332 PNG alpha.
--fixtures prepares independently decoded expected pixels for streaming tests.
--preview composes actual MIFs with live-value examples (never baked into ROM).
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile
from PIL import Image

sys.dont_write_bytecode = True
from build_jungle_assets import parse_mif, rgb
from supplied_floor_tiles import load
from implement_v4_graphics import floor_map, NAMES

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/jungle/hud_implemented'
SHA = '0958234d18a4b736158f181d3b7b225cca530603d0dd720f844111cf8e084305'
FIELDS = [('score',62,141,2,0xF9), ('high_score',62,190,2,0xF9),
          ('ruby',70,259,3,0xED), ('sapphire',70,292,3,0x57), ('cursed',70,325,3,0xB3)]
# Conservative interiors measured in the supplied native panel, not its decorations.
WINDOWS = [(34,113,90,132),(34,162,90,181),(54,233,95,247),
           (54,266,95,280),(54,299,95,313)]


def build_results(output):
    """Inspect completed reports only; never compiles or alters configuration."""
    def read(folder):
        result = {'stages': {}}
        for stage in ['map','fit','sta','asm']:
            text=(folder/('Lab1Demo.'+stage+'.rpt')).read_text()
            totals=re.search(r'was successful\.\s*(\d+) errors,\s*(\d+) warnings',text)
            assert totals and int(totals[1])==0, 'Incomplete/failed '+stage
            from collections import Counter
            codes=Counter(re.findall(r'^\s*(?:Critical )?Warning(?: \((\d+)\))?:',text,re.M))
            result['stages'][stage]=dict(errors=int(totals[1]),warnings=int(totals[2]),codes=dict(codes))
        text=(folder/'Lab1Demo.sta.summary').read_text()
        timing=re.findall(r"Type\s*:\s*(.+?)\s+'([^']+)'\s*\nSlack\s*:\s*([-+\d.]+)\s*\nTNS\s*:\s*([-+\d.]+)",text)
        assert timing and all(float(s)>0 and float(t)==0 for _,_,s,t in timing), 'Timing failed'
        # Require setup/hold sign-off for the actual game clock at every corner.
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
    result=dict(baseline_7201242=read(ROOT/'db/phase3a4_build/source/output_files'),hud=read(output))
    print(json.dumps(result,indent=2))
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--archive', type=Path)
    p.add_argument('--mask', action='store_true')
    p.add_argument('--fixtures', action='store_true')
    p.add_argument('--preview', action='store_true')
    p.add_argument('--git-index', action='store_true')
    p.add_argument('--build-results', type=Path)
    args = p.parse_args()
    raw = (ROOT / 'RTL/mifs/hud_panel_rgb332.mif').read_bytes()
    assert hashlib.sha256(raw).hexdigest() == SHA, 'Approved MIF changed'
    w,d,codes = parse_mif(raw.decode())
    assert (w,d) == (8,120*432)
    supplied = Image.open(OUT / 'hud_panel_rgb332.png').convert('RGBA')
    assert supplied.size == (120,432)
    pixels = list(supplied.get_flattened_data())
    assert {v[3] for v in pixels} == {0,255}
    alpha = [int(v[3] == 255) for v in pixels]
    assert sum(alpha) == 34177 and sum(v==0 and a for v,a in zip(codes,alpha)) == 12223
    assert all(v == 0 for v,a in zip(codes,alpha) if not a)
    assert max(abs(c-t) for v,px,a in zip(codes,pixels,alpha) if a for c,t in zip(rgb(v),px[:3])) <= 1
    if args.archive:
        with zipfile.ZipFile(args.archive) as z:
            assert raw == z.read('hud_panel_rgb332.mif')
            assert (OUT/'hud_panel_rgb332.png').read_bytes() == z.read('hud_panel_rgb332.png')
    if args.git_index:
        assert raw == subprocess.check_output(['git','show',':RTL/mifs/hud_panel_rgb332.mif'],cwd=ROOT)
    mask_path = ROOT / 'RTL/mifs/hud_panel_alpha.mif'
    mask = 'WIDTH=1;\nDEPTH=51840;\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n' + ''.join(
        f'{i} : {a};\n' for i,a in enumerate(alpha)) + 'END;\n'
    if args.mask:
        mask_path.write_text(mask, encoding='ascii')
    assert parse_mif(mask_path.read_text()) == (1,51840,alpha)
    layout = (ROOT/'RTL/VGA/jungle_hud_layout.svh').read_text()
    parameters = dict((k,int(v)) for k,v in re.findall(r'(\w+)=(\d+)',layout))
    assert [parameters[k] for k in ['HUD_LEFT','HUD_TOP','HUD_RIGHT','HUD_BOTTOM']] == [8,24,128,456]
    assert [parameters[k] for k in ['SCORE_X','SCORE_Y','HIGH_SCORE_X','HIGH_SCORE_Y','RELIC_X',
                                   'RUBY_Y','SAPPHIRE_Y','CURSED_Y','HUD_DIGIT_WIDTH','HUD_DIGIT_HEIGHT']] == [
        62,141,62,190,70,259,292,325,8,9]
    for (name,x,y,digits,_), (l,t,r,b) in zip(FIELDS,WINDOWS):
        assert l+8 <= x and x+digits*8 <= r+8 and t+24 <= y and y+9 <= b+24, name
        assert all(alpha[(py-24)*120+px-8] for py in range(y,y+9) for px in range(x,x+digits*8))
    _,_,font = parse_mif((ROOT/'RTL/mifs/numbers_new_font.mif').read_text())
    # Unused vertical padding is discarded only in addressing, never in the font MIF.
    for digit in range(10):
        assert not any(font[digit*512:digit*512+6*16])
        assert not any(font[digit*512+24*16:(digit+1)*512])
    glyphs = [tuple(font[digit*512+(6+2*y)*16+2*x] for y in range(9) for x in range(8)) for digit in range(10)]
    assert len(set(glyphs)) == 10 and all(any(g) for g in glyphs)
    fixture = ROOT/'db/jungle_hud_fixture'
    if args.fixtures:
        fixture.mkdir(parents=True,exist_ok=True)
        for name,values in [('panel',codes),('alpha',alpha),('font',font)]:
            digits = 2 if name == 'panel' else 1
            (fixture/(name+'.hex')).write_text(''.join(f'{v:0{digits}x}\n' for v in values))
    if args.preview:
        old=json.loads((ROOT/'assets/jungle/implemented/arena_map.json').read_text())
        blocked={tuple(p) for p in old['blocked']};g=floor_map(blocked)
        merged=[d if d&7>=4 else g[i] for i,d in enumerate(old['descriptor'])]
        scene=Image.new('RGB',(640,480),rgb(4))
        tiles=[load(n)[1] for n in NAMES]
        rotations=[None,Image.Transpose.ROTATE_270,Image.Transpose.ROTATE_180,Image.Transpose.ROTATE_90]
        for i,desc in enumerate(merged):
            tile=tiles[desc&7]
            if desc>>3: tile=tile.transpose(rotations[desc>>3])
            scene.paste(tile,(144+(i%20)*24,24+(i//20)*24),tile)
        pose=[(10,10),(10,11),(10,12),(10,13),(10,14),(11,14),(12,14),(13,14),
              (13,13),(13,12),(13,11),(13,10),(13,9),(13,8),(13,7),(13,6)]
        objects=[('snake_body_24',x,y) for x,y in pose]+[
            ('snake_head_24',10,9),('red_apple_24',7,3),('blue_apple_24',5,10),('black_apple_24',12,6)]
        for name,x,y in objects:
            _,sprite=load(name);scene.paste(sprite,(144+x*24,24+y*24),sprite)
        assert scene.crop((144,24,624,456)).tobytes()==Image.open(
            ROOT/'assets/jungle/v4_implemented/full_scene_640x480.png').crop((144,24,624,456)).tobytes()
        panel=Image.new('RGBA',(120,432))
        panel.putdata([(*rgb(v),255*a) for v,a in zip(codes,alpha)])
        scene.paste(panel,(8,24),panel)
        scene.save(OUT/'empty_hud_scene_640x480.png')
        # Examples are only in this preview; the active panel MIF has empty windows.
        values=['12','19','012','345','678']
        for (name,x,y,digits,col),value in zip(FIELDS,values):
            for i,letter in enumerate(value):
                for dy in range(9):
                    for dx in range(8):
                        if font[int(letter)*512+(6+2*dy)*16+2*dx]:
                            scene.putpixel((x+i*8+dx,y+dy),rgb(col))
        scene.save(OUT/'full_scene_640x480.png')
        scene.crop((8,24,128,456)).resize((480,1728),Image.Resampling.NEAREST).save(OUT/'live_hud_4x.png')
        (OUT/'verification.json').write_text(json.dumps(dict(mif_sha256=SHA,dimensions=[120,432],
            opaque_pixels=sum(alpha),transparent_pixels=len(alpha)-sum(alpha),opaque_black_pixels=12223,
            alpha_sha256=hashlib.sha256(mask_path.read_bytes()).hexdigest(),fields=FIELDS,windows=WINDOWS,
            glyph_width=8,glyph_height=9,duplicate_icons=False,arena_matches_v4=True),indent=2)+'\n')
    if args.build_results:
        build_results(args.build_results)
    print('JUNGLE_HUD_ASSETS_PASS: exact 120x432 RGB332 panel; alpha independent of00; five compact live fields; no duplicate icons; V4 arena unchanged')


if __name__ == '__main__':
    main()
