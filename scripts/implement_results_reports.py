"""Lossless supplied-results integration, independent previews and build audit.

No artwork generation. Original archive entries remain byte-identical. Derived
atlases concatenate supplied MIF words and existing glyph/relic data only.
"""
import argparse
import difflib
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image
from build_jungle_assets import parse_mif, rgb
from implement_final_hud import arena_scene, numbers, inspect_build, REGIONS

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/jungle/shared_results_supplied'
OUT = ROOT / 'assets/jungle/shared_results_implemented'
MIFS = ROOT / 'RTL/mifs/results'
FIX = ROOT / 'db/results_fixture'
PATCHES = [
    ('victory_title_224x32', 280, 40, 224, 32, 1),
    ('defeat_title_224x32', 280, 40, 224, 32, 2),
    ('victory_emblem_160x72', 312, 80, 160, 72, 1),
    ('defeat_emblem_160x72', 312, 80, 160, 72, 2),
    ('victory_plaque_224x32', 280, 164, 224, 32, 1),
    ('defeat_score_label_136x16', 280, 172, 136, 16, 2),
]
SPRITES = ['red_apple_24', 'blue_apple_24', 'black_apple_24']
FIELDS = [(456,171,2,0xF9), (440,235,3,0xED),
          (440,291,3,0x57), (440,347,3,0xB3)]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_mif(path, width, values):
    path.write_text(f'WIDTH={width};\nDEPTH={len(values)};\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n' +
                    ''.join(f'{i} : {v:02X};\n' for i,v in enumerate(values)) + 'END;\n', encoding='ascii')


def assets():
    manifest = json.loads((SOURCE/'manifest.json').read_text())
    result = {}
    with zipfile.ZipFile('C:/Users/USER/Downloads/FPGA_Jungle_Temple_Shared_Results_Assets.zip') as archive:
        for entry in archive.infolist():
            assert entry.filename == Path(entry.filename).name, 'Unexpected archive hierarchy'
            assert archive.read(entry) == (SOURCE/entry.filename).read_bytes(), 'Archive entry changed'
    for name, desc in manifest['assets'].items():
        raw = (SOURCE/(name+'_rgb332.mif')).read_bytes()
        assert sha(raw) == desc['rgb332_sha256']
        width, depth, pixels = parse_mif(raw.decode())
        assert (width,depth) == (8,desc['width']*desc['height'])
        png = SOURCE/(name+'.png')
        assert sha(png.read_bytes()) == desc['png_sha256']
        image = Image.open(png).convert('RGBA')
        assert image.size == (desc['width'],desc['height'])
        mask = [1]*depth
        if desc['mask_bits']:
            raw_mask = (SOURCE/(name+'_mask1.mif')).read_bytes()
            assert sha(raw_mask) == desc['mask_mif_sha256']
            mw,md,mask = parse_mif(raw_mask.decode())
            assert (mw,md) == (1,depth)
        # PNG expansion can round channel levels; compare quantized codes.
        encoded = [(round(r*7/255)<<5)|(round(g*7/255)<<2)|round(b*3/255)
                   for r,g,b,a in image.get_flattened_data()]
        assert encoded == pixels, name+' PNG/MIF pixel mismatch'
        assert [int(a!=0) for r,g,b,a in image.get_flattened_data()] == mask, name+' alpha mismatch'
        result[name] = (pixels,mask)
    return result


def bdf_transform(text, top):
    """Add display-only taps. Run equally on working and HEAD schematic text."""
    crlf='\r\n' in text
    text=text.replace('\r\n','\n')
    counts = ['rubyCountBCD[11..0]', 'sapphireCountBCD[11..0]', 'cursedCountBCD[11..0]']
    def port(name,x,y,kind):
        return (f'\t(port\n\t\t(pt {x} {y})\n\t\t({kind})\n'
                f'\t\t(text "{name}" (rect 0 0 180 12)(font "Arial" ))\n'
                f'\t\t(text "{name}" (rect {21 if x==0 else 90} {y-5} {210 if x==0 else x-10} {y+7})(font "Arial" ))\n'
                f'\t\t(line (pt {x} {y})(pt {16 if x==0 else x-16} {y})(line_width 3))\n\t)\n')
    def connector(name,x,y,x2):
        return (f'(connector\n\t(text "{name}" (rect {min(x,x2)+8} {y-16} {max(x,x2)+180} {y+1})(font "Arial" ))\n'
                f'\t(pt {x} {y})\n\t(pt {x2} {y})\n\t(bus)\n)\n')
    if top:
        marker='\t(text "end_message_display"'
        begin=text.rfind('(symbol',0,text.index(marker))
        end=text.index('\n(symbol',begin+1)
        chunk=text[begin:end]
        assert '(rect -696 112 -448 288)' in chunk
        chunk=chunk.replace('(rect -696 112 -448 288)','(rect -696 112 -448 384)')
        chunk=chunk.replace('(rect 16 16 232 160)','(rect 16 16 232 256)')
        names=['scoreLow[3..0]','scoreHigh[3..0]']+counts
        addition=''.join(port(n,0,160+i*16,'input') for i,n in enumerate(names))
        at=chunk.index('\t(drawing\n')
        chunk=chunk[:at]+addition+chunk[at:]
        text=text[:begin]+chunk+text[end:]
        text+=''.join(connector(n,-840,272+i*16,-696) for i,n in enumerate(names))
        marker='\t(text "Score_Block"'
        begin=text.rfind('(symbol',0,text.index(marker));end=text.index('\n(symbol',begin+1)
        chunk=text[begin:end].replace('(rect 72 720 360 912)','(rect 72 720 360 960)')
        chunk=chunk.replace('(rect 16 16 272 176)','(rect 16 16 272 224)')
        at=chunk.index('\t(drawing\n')
        chunk=chunk[:at]+''.join(port(n,288,144+i*16,'output') for i,n in enumerate(counts))+chunk[at:]
        text=text[:begin]+chunk+text[end:]
        text+=''.join(connector(n,360,864+i*16,520) for i,n in enumerate(counts))
    else:
        # The named buses already exist internally; these ports expose the same nets.
        for i,n in enumerate(counts):
            y=1360+i*32
            text+=(f'(pin\n\t(output)\n\t(rect -2700 {y-8} -2400 {y+8})\n'
                   '\t(text "OUTPUT" (rect 1 0 39 10)(font "Arial" (font_size 6)))\n'
                   f'\t(text "{n}" (rect 90 0 280 12)(font "Arial" ))\n\t(pt 0 8)\n'
                   '\t(drawing\n\t\t(line (pt 0 8)(pt 52 8))\n\t\t(line (pt 52 4)(pt 78 4))\n'
                   '\t\t(line (pt 52 12)(pt 78 12))\n\t\t(line (pt 52 12)(pt 52 4))\n'
                   '\t\t(line (pt 78 4)(pt 82 8))\n\t\t(line (pt 82 8)(pt 78 12))\n\t)\n)\n')
            text+=connector(n,-2850,y,-2700)
    return text.replace('\n','\r\n') if crlf else text


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--install',action='store_true')
    parser.add_argument('--preview',action='store_true')
    parser.add_argument('--bdf-patch',action='store_true')
    parser.add_argument('--index-patch',action='store_true')
    parser.add_argument('--audit',action='store_true')
    parser.add_argument('--git-index',action='store_true')
    parser.add_argument('--build-results',type=Path)
    args=parser.parse_args()
    if args.git_index:
        expected={'.gitattributes','RTL/VGA/End_Message_Display.sv','RTL/VGA/Score_Block.bdf',
                  'RTL/VGA/TOP_VGA_DEMO.bdf','simulation/opening_screen_tb.sv',
                  'RTL/VGA/results_report_renderer.svh','scripts/implement_results_reports.py',
                  'simulation/results_reports_tb.sv','simulation/results_reports.do','RESULTS_SCREEN_IMPLEMENTATION.md'}
        for folder in [MIFS,SOURCE,OUT]:
            expected.update(p.relative_to(ROOT).as_posix() for p in folder.rglob('*') if p.is_file())
        staged=set(subprocess.check_output(['git','diff','--cached','--name-only'],cwd=ROOT).decode().splitlines())
        assert staged==expected, f'Unexpected/missing staged files: {staged ^ expected}'
        for name in sorted(staged):
            contents=subprocess.check_output(['git','show',':'+name],cwd=ROOT)
            if name.endswith('.bdf'):
                head=subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT).decode()
                assert contents==bdf_transform(head,name.endswith('TOP_VGA_DEMO.bdf')).encode(), 'Unrelated schematic changes staged'
            elif name.startswith(('RTL/mifs/results/','assets/jungle/shared_results_supplied/')) or name.endswith('.png'):
                assert contents==(ROOT/name).read_bytes(), 'Staged asset byte mismatch: '+name
            else:
                assert contents.replace(b'\r\n',b'\n')==(ROOT/name).read_bytes().replace(b'\r\n',b'\n'), 'Staged source mismatch: '+name
        print(f'GIT_INDEX_PASS: exactly{len(staged)} task files; authoritative assets byte-identical; BDF task additions only; QSF/user changes excluded')
    if args.audit:
        baseline=ROOT/'db/results_implementation_baseline'
        for name in ['Lab1Demo.qsf','RTL/VGA/TOP_VGA_DEMO.bdf','RTL/VGA/Score_Block.bdf']:
            original=(baseline/Path(name).name).read_text()
            expected=bdf_transform(original,name.endswith('TOP_VGA_DEMO.bdf')) if name.endswith('.bdf') else original
            assert (ROOT/name).read_text()==expected, 'Unexpected schematic/configuration change: '+name
        manifest=json.loads((ROOT/'db/supplied_opening_build/source_manifest.json').read_text(encoding='utf-8-sig'))
        protected={name:digest for name,digest in manifest.items()
                   if name.startswith(('RTL/','constraints/','CLK_31P5')) and
                   name not in ['RTL/VGA/End_Message_Display.sv','RTL/VGA/TOP_VGA_DEMO.bdf','RTL/VGA/Score_Block.bdf']}
        for name,digest in protected.items():
            assert sha((ROOT/name).read_bytes()).upper()==digest.upper(), 'Protected source changed: '+name
        current=(ROOT/'RTL/VGA/End_Message_Display.sv').read_text()
        old=(baseline/'End_Message_Display.sv').read_text()
        extract=lambda text:text[text.index('logic menuActive;'):text.index('//------------- Area Detection' if '//------------- Area Detection' in text else '// Shared results renderer')]
        assert extract(current)==extract(old), 'Opening-screen path changed'
        assert 'end_message_win.mif' not in current and 'end_message_lost.mif' not in current
        print(f'PRESERVATION_PASS: {len(protected)} RTL/MIF/constraint/IP files byte-identical; QSF unchanged; BDF additions only; opening path unchanged')
    if args.bdf_patch or args.index_patch:
        files=['RTL/VGA/Score_Block.bdf','RTL/VGA/TOP_VGA_DEMO.bdf']
        patches=[]
        for name in files:
            old=(subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT).decode()
                 if args.index_patch else (ROOT/name).read_text())
            new=bdf_transform(old,name.endswith('TOP_VGA_DEMO.bdf'))
            diff=list(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+name,tofile='b/'+name))
            if args.index_patch: patches.extend(diff)
            else:
                patches.append('*** Update File: '+name+'\n')
                patches.extend('@@\n' if line.startswith('@@') else line for line in diff[2:])
        if args.index_patch:
            target=ROOT/'db/results_fixture/bdf_index.patch';target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(''.join(patches).encode('utf-8'))
        else: print('*** Begin Patch\n'+''.join(patches)+'*** End Patch')
        return
    data=assets()
    colors=[];masks=[];descriptors=[]
    for name,x,y,w,h,state in PATCHES:
        pixels,alpha=data[name]
        descriptors.append(dict(name=name,x=x,y=y,w=w,h=h,state=state,offset=len(colors)))
        colors+=pixels;masks+=alpha
    for i,name in enumerate(SPRITES):
        w,d,pixels=parse_mif((ROOT/'RTL/mifs'/(name+'.mif')).read_text())
        assert (w,d)==(8,576)
        descriptors.append(dict(name=name,x=280,y=232+i*56,w=24,h=24,state=0,offset=len(colors)))
        colors+=pixels;masks += [int(v!=255) for v in pixels]
    assert len(colors)==len(masks)==48448
    if args.install:
        MIFS.mkdir(parents=True,exist_ok=True)
        # Install originals byte-for-byte, preserving authoritative supplied MIFs.
        for source in SOURCE.glob('*.mif'):
            (MIFS/source.name).write_bytes(source.read_bytes())
        write_mif(MIFS/'results_details_rgb332.mif',8,colors)
        write_mif(MIFS/'results_details_mask1.mif',1,masks)
    assert parse_mif((MIFS/'results_details_rgb332.mif').read_text())==(8,len(colors),colors)
    assert parse_mif((MIFS/'results_details_mask1.mif').read_text())==(1,len(masks),masks)
    for source in SOURCE.glob('*.mif'):
        assert (MIFS/source.name).read_bytes()==source.read_bytes()
    if args.preview:
        OUT.mkdir(parents=True,exist_ok=True);FIX.mkdir(parents=True,exist_ok=True)
        bg=data['report_shared_144x216'][0]
        _,_,font=parse_mif((ROOT/'RTL/mifs/numbers_new_font.mif').read_text())
        _,_,hud=parse_mif((ROOT/'RTL/mifs/hud_frame_rgb332.mif').read_text())
        arena=arena_scene()
        offset=0
        for _,x,y,w,h in REGIONS:
            tile=Image.new('RGB',(w,h));tile.putdata([rgb(v) for v in hud[offset:offset+w*h]])
            arena.paste(tile,(x,y));offset+=w*h
        base=arena.copy()
        # Preview fixtures are composed from each authoritative MIF independently,
        # NOT by the production atlas address-selection implementation.
        for state,label in [(1,'victory'),(2,'defeat')]:
            panel=[]
            for y in range(432):
                panel.extend(bg[(y//2)*144+x//2] for x in range(288))
            for d in descriptors:
                if d['state'] not in (0,state):continue
                name=d['name']
                if name in data:pixels,alpha=data[name]
                else:
                    _,_,pixels=parse_mif((ROOT/'RTL/mifs'/(name+'.mif')).read_text())
                    alpha=[int(v!=255) for v in pixels]
                for j,(v,a) in enumerate(zip(pixels,alpha)):
                    if a:panel[(d['y']-24+j//d['w'])*288+d['x']-248+j%d['w']]=v
            (FIX/(label+'_static.hex')).write_text(''.join(f'{v:02x}\n' for v in panel))
            tile=Image.new('RGB',(288,432));tile.putdata([rgb(v) for v in panel])
            sample=(['92','089','001','000'],'92') if state==1 else (['67','034','016','003'],'90')
            for suffix,values,high in [('sample',*sample),('zero',['00','000','000','000'],'00'),('max',['99','999','999','999'],'99')]:
                scene=numbers(base,font,[values[0],high]+values[1:]);scene.paste(tile,(248,24))
                for i,((x,y,digits,color),value) in enumerate(zip(FIELDS,values)):
                    if i==0 and state==1:continue
                    for n,letter in enumerate(value):
                        for dy in range(18):
                            for dx in range(16):
                                if font[int(letter)*512+(6+dy)*16+dx]:scene.putpixel((x+n*16+dx,y+dy),rgb(color))
                # All pixels outside the report are exactly the existing scene/HUD.
                reference=numbers(base,font,[values[0],high]+values[1:])
                for region in [(0,0,248,480),(536,0,640,480),(248,0,536,24),(248,456,536,480)]:
                    assert scene.crop(region).tobytes()==reference.crop(region).tobytes()
                scene.save(OUT/(label+'_'+suffix+'_640x480.png'))
                if suffix=='sample':scene.resize((1280,960),Image.Resampling.NEAREST).save(OUT/(label+'_2x.png'))
        (FIX/'font.hex').write_text(''.join(f'{v:x}\n' for v in font))
        # Freeze previous renderer for MENU-only cycle comparisons.
        legacy=subprocess.check_output(['git','show','ddde7c3:RTL/VGA/End_Message_Display.sv'],cwd=ROOT)
        (FIX/'previous_end_message_display.sv').write_bytes(legacy.replace(b'module end_message_display (',b'module previous_end_message_display (',1))
        (OUT/'verification.json').write_text(json.dumps(dict(
            archive_sha256=sha(Path('C:/Users/USER/Downloads/FPGA_Jungle_Temple_Shared_Results_Assets.zip').read_bytes()),
            source_mif_sha256={p.name:sha(p.read_bytes()) for p in SOURCE.glob('*.mif')},
            panel_bounds=[248,24,536,456],base_size=[144,216],scale=2,details=descriptors,
            details_pixels=len(colors),details_mask_bits=len(masks),shared_background_pixels=len(bg),
            original_assets_byte_identical=True,existing_hud_unchanged=True,
            art_generated=False,hardware_tested=False),indent=2)+'\n')
    if args.build_results:
        build_manifest=json.loads((args.build_results.parents[1]/'source_manifest.json').read_text(encoding='utf-8-sig'))
        hardware_suffixes={'.sv','.svh','.v','.bdf','.mif','.qsf','.qpf','.qip','.sdc','.tcl','.qxp','.stp','.hex'}
        compiled_inputs={n:s for n,s in build_manifest.items() if Path(n).suffix.lower() in hardware_suffixes}
        for name,digest in compiled_inputs.items():
            assert sha((ROOT/name).read_bytes()).upper()==digest.upper(),'Working input differs from compiled snapshot: '+name
        current=inspect_build(args.build_results)
        baseline=inspect_build(ROOT/'db/supplied_opening_build/source/output_files')
        lines=(args.build_results/'Lab1Demo.fit.rpt').read_text().splitlines()
        rows=[line for line in lines if 'ALTSYNCRAM' in line and 'M10K_X' in line]
        locations=lambda r:set(re.findall(r'M10K_X\d+_Y\d+_N\d+','\n'.join(r)))
        report_rows=[r for r in rows if 'results_report_renderer:results' in r]
        assert report_rows and not any('end_message_win.mif' in r or 'end_message_lost.mif' in r for r in rows)
        result=dict(baseline=baseline,current=current,measured_total_m10k=len(locations(rows)),
                    measured_results_m10k=len(locations(report_rows)),
                    verified_compilation_inputs=len(compiled_inputs),
                    obsolete_result_roms_removed=True)
        (OUT/'quartus_results.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result,indent=2))
    print('RESULTS_ASSETS_PASS: supplied originals byte-identical; lossless native atlas; independent masks; no generated artwork')


if __name__=='__main__':main()
