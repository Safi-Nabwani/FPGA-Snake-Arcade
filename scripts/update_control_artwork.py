"""Patch only native ROM instruction pixels; preserve dimensions, alpha and RTL.

Requires the saved pre-edit ROMs in db/control_artwork_baseline/mifs.
Run --install once to write the three active MIFs, then without it to verify
and reconstruct actual-ROM previews. Supplied source artwork stays untouched.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
from PIL import Image
from build_jungle_assets import parse_mif, rgb
from implement_results_v3 import tiled, write_mif, FIELDS, FONT_X, FONT_Y
from implement_final_hud import numbers

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'db/control_artwork_baseline/mifs'
ACTIVE = ROOT / 'RTL/mifs'
OUT = ROOT / 'assets/jungle/control_artwork_update'
REGIONS = json.loads((ROOT / 'assets/jungle/supplied_opening_implemented/verification.json').read_text())['regions']


def read(path):
    return parse_mif(path.read_text())


def opening_address(x, y):
    for r in REGIONS:
        if r['x'] <= x < r['x'] + r['width'] and r['y'] <= y < r['y'] + r['height']:
            return r['offset'] + (y-r['y'])*r['width'] + x-r['x']
    return (y//4)*124+x//4


def panels(folder):
    w, n, tilemap = read(folder/'results_tilemap.mif')
    pw, pn, payload = read(folder/'results_tiles_rgba9.mif')
    assert (w,n,pw,pn) == (15,62208,9,69628)
    result = {}
    for state_index, state in enumerate(('victory','defeat')):
        words = [payload[4*tilemap[state_index*31104+(y//2)*144+x//2]+(y%2)*2+x%2]
                 for y in range(432) for x in range(288)]
        result[state] = ([v & 255 for v in words], [v >> 8 for v in words])
    return result


def glyphs():
    text = (ROOT/'RTL/VGA/hud_labels.sv').read_text()
    result = {k:v.replace('_','') for k,v in re.findall(r'"(.)": glyph = 35\'b([01_]+)',text)}
    # Same project 5x7 character forms used by the existing opening converter.
    result.update({
        'M':'10001_11011_10101_10101_10001_10001_10001',
        'N':'10001_11001_10101_10011_10001_10001_10001',
        'T':'11111_00100_00100_00100_00100_00100_00100',
        'F':'11111_10000_10000_11110_10000_10000_10000',
        'W':'10001_10001_10001_10101_10101_10101_01010',
        '4':'00010_00110_01010_10010_11111_00010_00010',
        '5':'11111_10000_10000_11110_00001_00001_11110',
        '6':'01110_10000_10000_11110_10001_10001_01110',
        '8':'01110_10001_10001_01110_10001_10001_01110',
        '/':'00001_00010_00010_00100_01000_01000_10000',
        ' ':'0'*35,
    })
    return {k:v.replace('_','') for k,v in result.items()}


def update_pixels(colors, width, box, labels, opaque=None):
    """Labels: text, x, y, X scale, Y scale, character pitch, row colors."""
    left, top, right, bottom = box
    for y in range(top,bottom):
        for x in range(left,right):
            if opaque is not None:
                assert opaque[y*width+x] == 1, 'Cannot clear transparent decoration'
            colors[y*width+x] = 0x04 if opaque is None else 0x00
    font = glyphs()
    for text,x,y,sx,sy,pitch,inks in labels:
        for i,letter in enumerate(text):
            for row in range(7):
                for col in range(5):
                    if font[letter][row*5+col] == '1':
                        for dy in range(sy):
                            for dx in range(sx):
                                xx,yy = x+i*pitch+col*sx+dx, y+row*sy+dy
                                assert left<=xx<right and top<=yy<bottom
                                colors[yy*width+xx] = inks[min(row,len(inks)-1)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install',action='store_true')
    args = parser.parse_args()
    ow,on,old_atlas = read(BASE/'opening_supplied_atlas.mif')
    assert (ow,on)==(8,104476)
    old_open = [old_atlas[opening_address(x,y)] for y in range(480) for x in range(496)]
    new_open = old_open.copy()
    boxes = []
    # Preserve the supplied keycap borders, changing only their arrow interiors.
    for box,label,x,y in [((76,250,96,270),'8',81,252),
                          ((44,280,64,300),'4',49,282),
                          ((108,280,128,300),'6',113,282),
                          ((76,309,96,329),'5',81,312)]:
        update_pixels(new_open,496,box,[(label,x,y,2,2,12,[0xFE,0xFE,0xF9,0xF9,0xF9,0xF4,0xF4])])
        boxes.append(box)
    box = (22,338,158,372)
    update_pixels(new_open,496,box,[
        ('8 UP  5 DOWN',54,339,1,1,6,[0xFE]),
        ('4 LEFT 6 RIGHT',48,350,1,1,6,[0xFE]),
        ('ENTER START/RESTART',36,362,1,1,6,[0xFE])])
    boxes.append(box)
    box = (106,417,392,446)
    text = 'PRESS ENTER TO START'
    update_pixels(new_open,496,box,[(text,129,421,2,3,12,[0xFE,0xFE,0xF9,0xF9,0xF4,0xF4,0xF0])])
    boxes.append(box)
    atlas = old_atlas.copy()
    for y in range(480):
        for x in range(496):
            if new_open[y*496+x] != old_open[y*496+x]:
                address = opening_address(x,y)
                assert address>=14880, 'Text patch would alter stretched background'
                atlas[address] = new_open[y*496+x]
    full = panels(BASE/'results_v3')
    expected = {}
    result_boxes = {'victory':(58,389,230,404),'defeat':(65,378,224,391)}
    for state,(colors,mask) in full.items():
        expected[state] = (colors.copy(),mask.copy())
        box = result_boxes[state]
        # Existing dark numeral plaque, surrounding trim/ornaments untouched.
        x = (box[0]+box[2]-(22*7-2))//2
        y = box[1]+3
        update_pixels(expected[state][0],288,box,
                      [('PRESS ENTER TO RESTART',x,y,1,1,7,[0xFE])],mask)
    dictionary,tilemap,unique = tiled(expected,2)
    assert len(dictionary)<=69628, 'New labels exceed existing physical ROM budget'
    dictionary += [0]*(69628-len(dictionary))
    if args.install:
        write_mif(ACTIVE/'opening_supplied_atlas.mif',8,atlas)
        write_mif(ACTIVE/'results_v3/results_tilemap.mif',15,tilemap)
        write_mif(ACTIVE/'results_v3/results_tiles_rgba9.mif',9,dictionary)
    assert read(ACTIVE/'opening_supplied_atlas.mif') == (8,104476,atlas)
    assert read(ACTIVE/'results_v3/results_tilemap.mif') == (15,62208,tilemap)
    assert read(ACTIVE/'results_v3/results_tiles_rgba9.mif') == (9,69628,dictionary)
    actual = panels(ACTIVE/'results_v3')
    proof = {}
    def inside(x,y,rects):
        return any(l<=x<r and t<=y<b for l,t,r,b in rects)
    changed = [i for i,(a,b) in enumerate(zip(old_open,new_open)) if a!=b]
    assert all(inside(i%496,i//496,boxes) for i in changed)
    assert [atlas[opening_address(x,y)] for y in range(480) for x in range(496)] == new_open
    proof['opening_changed_pixels'] = len(changed)
    OUT.mkdir(parents=True,exist_ok=True)
    _,_,font = read(ACTIVE/'numbers_new_font.mif')
    _,_,hud = read(ACTIVE/'hud_frame_rgb332.mif')
    scene = Image.new('RGB',(640,480))
    right = Image.new('RGB',(496,480));right.putdata([rgb(v) for v in new_open]);scene.paste(right,(144,0))
    sidebar = Image.new('RGB',(144,480));sidebar.putdata([rgb(v) for v in hud[:69120]]);scene.paste(sidebar,(0,0))
    scene = numbers(scene,font,['00','00','000','000','000'])
    scene.save(OUT/'opening_640x480.png')
    scene.resize((1280,960),Image.Resampling.NEAREST).save(OUT/'opening_2x.png')
    for state,(colors,mask) in actual.items():
        assert (colors,mask) == expected[state]
        old_colors,old_mask = full[state]
        assert mask == old_mask, 'Results alpha changed'
        changed = [i for i,(a,b) in enumerate(zip(old_colors,colors)) if a!=b]
        assert all(inside(i%288,i//288,[result_boxes[state]]) for i in changed)
        proof[state+'_changed_pixels'] = len(changed)
        panel = Image.new('RGBA',(288,432));panel.putdata([(*rgb(c),a*255) for c,a in zip(colors,mask)])
        panel.save(OUT/(state+'_panel_288x432.png'))
        scene = Image.open(ROOT/('assets/jungle/results_v3_implemented/'+state+'_zero_640x480.png')).convert('RGB')
        previous = scene.copy();scene.paste(panel,(248,24),panel)
        for x,y,count,ink in FIELDS[state]:
            for digit in range(count):
                for dy,fy in enumerate(FONT_Y):
                    for dx,fx in enumerate(FONT_X):
                        if font[fy*16+fx]: scene.putpixel((x+digit*12+dx,y+dy),rgb(ink))
        assert scene.crop((0,0,144,480)).tobytes()==previous.crop((0,0,144,480)).tobytes()
        scene.save(OUT/(state+'_640x480.png'))
    rtl = (ROOT/'RTL/VGA/End_Message_Display.sv').read_text()
    assert 'RTL/mifs/opening_supplied_atlas.mif' in rtl
    rtl = (ROOT/'RTL/VGA/results_report_renderer.svh').read_text()
    assert all(name in rtl for name in ('results_tilemap.mif','results_tiles_rgba9.mif','69628','62208'))
    proof.update(unique_result_tiles=unique,rom_dimensions_unchanged=True,
                 outside_instruction_boxes_unchanged=True,all_result_alpha_unchanged=True,
                 opening_boxes_right_local=boxes,results_boxes_panel_local=result_boxes,
                 text=['8 UP  5 DOWN','4 LEFT 6 RIGHT','ENTER START/RESTART',
                       'PRESS ENTER TO START','PRESS ENTER TO RESTART'])
    (OUT/'verification.json').write_text(json.dumps(proof,indent=2)+'\n')
    print('CONTROL_ARTWORK_PASS '+json.dumps(proof))


if __name__=='__main__':
    main()
