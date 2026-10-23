"""Focused production input checks; no source edits or historical db fixtures."""
import hashlib,json,re,subprocess,sys
from pathlib import Path
from rom_assets import parse_mif
ROOT=Path(__file__).resolve().parents[1]

def main():
    manifest=json.loads((ROOT/'verification/source_sha256.json').read_text())
    for name,digest in manifest.items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
        if name.lower().endswith('.mif'):parse_mif((ROOT/name).read_text())
    qsf=(ROOT/'TheTemplesCurse.qsf').read_text()
    assert '5CSXFC6D6F31C6' in qsf and 'TOP_LEVEL_ENTITY TOP_VGA_DEMO' in qsf
    assert 'VIRTUAL_PIN ON -to "BG_RGB[*]"' in qsf and 'VIRTUAL_PIN ON -to borderDR' in qsf
    assert 'INITIAL_LENGTH = 14' in (ROOT/'RTL/VGA/snake_body.sv').read_text()
    assert 'MAX_SEGMENTS = 63' in (ROOT/'RTL/VGA/snake_body.sv').read_text()
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/build_emerald_bases.py')],cwd=ROOT,check=True)
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/integrate_approved_opening.py')],cwd=ROOT,check=True)
    w,d,songs=parse_mif((ROOT/'RTL/AUDIO/songs.mif').read_text())
    assert (w,d)==(16,4096) and songs[768:772]==[0x4441,0x3441,0xB041,0x9040]
    fixture=ROOT/'db/cursed_audio_build';fixture.mkdir(parents=True,exist_ok=True)
    (fixture/'golden.hex').write_text(''.join(f'{v:04x}\n' for v in songs))
    print(f'PRODUCTION_INPUTS_PASS {len(manifest)} unchanged inputs; MIF coverage; Emerald rotations; approved opening; cursed data; virtual pins')
if __name__=='__main__':main()
