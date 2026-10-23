"""Extract exact original bases and exhaustively verify all nine bits; no art edits."""
import argparse
from pathlib import Path
from rom_assets import parse_mif
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'RTL/mifs/snake_variants'
def main():
    p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');args=p.parse_args()
    w,d,original=parse_mif((DIR/'01_emerald_rgba9.mif').read_text());assert (w,d)==(9,8064)
    for name,indices in [('emerald_head_base_rgba9.mif',[0]),('emerald_body_bases_rgba9.mif',[4,5,6,7,10])]:
        values=[v for i in indices for v in original[i*576:(i+1)*576]]
        path=DIR/name
        if args.install:
            path.write_text(f'WIDTH=9;\nDEPTH={len(values)};\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n'+''.join(f'{i} : {v:X};\n' for i,v in enumerate(values))+'END;\n')
        assert parse_mif(path.read_text())==(9,len(values),values)
    bases=[0,0,0,0,4,5,6,7,6,7,10,10,10,10]
    turns=[0,1,2,3,0,0,0,0,3,1,0,1,2,3]
    for i in range(14):
        for y in range(24):
            for x in range(24):
                sx,sy=x,y
                for _ in range(turns[i]):sx,sy=sy,23-sx
                assert original[i*576+y*24+x]==original[bases[i]*576+sy*24+sx]
    fixture=ROOT/'db/sprite_opt_build';fixture.mkdir(parents=True,exist_ok=True)
    (fixture/'original.hex').write_text(''.join(f'{v:03x}\n' for v in original))
    print('EMERALD_BASES_PASS 8064 exact nine-bit pixels; 576 head + 2880 body words; original atlas preserved')
if __name__=='__main__':main()
