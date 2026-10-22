"""Verify bank-3-only edit, exact note words, and emit focused ROM oracle."""
from pathlib import Path
import argparse
from analyze_audio_note_timing import read_songs
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--baseline',action='store_true');args=p.parse_args()
    path=ROOT/'RTL/AUDIO/songs.mif';oldpath=ROOT/'db/cursed_audio_baseline/songs.mif'
    old=read_songs(oldpath);new=read_songs(path)
    if not args.baseline:
        assert [new[i] for i in range(0x300,0x304)]==[0x4441,0x3441,0xB041,0x9040]
        assert all(new[i]==0 for i in range(0x304,0x400))
        assert all(new[i]==old[i] for i in range(4096) if not 0x300<=i<0x400)
        def outside(p):
            b=p.read_bytes();return b.split(b'-- Notes for song explosion_Track_0.txt')[0],b.split(b'-- Notes for song miss_Track_0.txt')[1]
        assert outside(path)==outside(oldpath),'Other banks raw bytes changed'
    (ROOT/'db/cursed_audio_build/golden.hex').write_text(''.join(f'{new[i]:04x}\n' for i in range(4096)))
    print('CURSED_DATA_PASS all15otherbanks_byte_identical' if not args.baseline else 'BASELINE_ORACLE_READY')
if __name__=='__main__':main()
