"""Verify approved Ruby words and lossless preservation outside bank 5."""
import argparse
from pathlib import Path
from analyze_audio_note_timing import read_songs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    args = parser.parse_args()
    current = Path("RTL/AUDIO/songs.mif")
    old, new = read_songs(args.baseline), read_songs(current)
    assert [new[0x500 + i] for i in range(4)] == [0x7440, 0x0860, 0x2840, 0x78A0]
    assert all(new[i] == 0 for i in range(0x504, 0x600))
    assert all(old[i] == new[i] for i in range(4096) if not 0x500 <= i < 0x600)
    assert [new[i] for i in range(0x200, 0x203)] == [0x4861, 0x7861, 0x0CC2]
    # Raw bytes, not merely decoded words: all other bank text is unchanged.
    def outside_ruby(path):
        raw = path.read_bytes()
        start = raw.index(b"-- Notes for song miss_Track_0.txt")
        end_bank4 = raw.index(b"[402..4FF]: 0000;", start) + len(b"[402..4FF]: 0000;")
        bank6 = raw.index(b"-- Notes for song CrankyKongsThem_Track_3.txt")
        return raw[:end_bank4], raw[bank6:]
    assert outside_ruby(args.baseline) == outside_ruby(current)
    changed = [f"{i:03X}" for i in range(4096) if old[i] != new[i]]
    print(f"RUBY_BANK_PRESERVATION_PASS changed_addresses={changed} other_banks=15 byte_identical=1 sapphire_unchanged=1 cleared_tail=1")


if __name__ == "__main__":
    main()
