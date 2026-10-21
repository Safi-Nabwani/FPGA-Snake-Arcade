"""Read-only note-duration audit; does not edit songs or generate audio/art.

The old column is a source-derived calculation of duration LOADS for an
isolated request after settled idle bank 4. It is not an analog measurement.
Zero-gap old FSM transitions load the outgoing ROM word's duration; nonzero
gaps allow the next word to settle. Clock-scale enable delays/tick phase are
not represented by the nominal tick totals. New exact edge timing is tested
independently by simulation/audio_playback_priority_tb.sv.
"""
import json
import re
from pathlib import Path


def read_songs(path):
    data = {}
    for raw in path.read_text().splitlines():
        line = raw.split("--", 1)[0].strip()
        match = re.fullmatch(r"(?:\[([0-9A-F]+)\.\.([0-9A-F]+)\]|([0-9A-F]+))\s*:\s*([0-9A-F]+);", line, re.I)
        if not match:
            continue
        first = int(match[1] or match[3], 16)
        last = int(match[2] or match[3], 16)
        value = int(match[4], 16)
        for address in range(first, last + 1):
            if address in data or not 0 <= address < 4096 or not 0 <= value < 65536:
                raise ValueError("Invalid/duplicate song word")
            data[address] = value
    if len(data) != 4096:
        raise ValueError("Incomplete songs.mif")
    return data


def main():
    data = read_songs(Path(__file__).resolve().parents[1] / "RTL/AUDIO/songs.mif")
    results = []
    for bank, name in enumerate(("Victory", "Defeat", "Sapphire", "Cursed", "Direction / restart", "Ruby")):
        words = []
        for index in range(256):
            word = data[bank * 256 + index]
            if ((word >> 5) & 31) == 0:
                break
            words.append(word)
        else:
            raise ValueError("Missing terminator")
        durations = [(word >> 5) & 31 for word in words]
        gaps = [word & 31 for word in words]
        old_loads = [(data[4 * 256] >> 5) & 31]
        old_loads += [durations[i - 1] if gaps[i - 1] == 0 else durations[i] for i in range(1, len(words))]
        old_ticks, new_ticks = sum(old_loads) + sum(gaps), sum(durations) + sum(gaps)
        results.append(dict(bank=bank, effect=name, notes=len(words), old_calculated_loads=old_loads,
                            intended_and_verified_loads=durations, intended_gaps=gaps,
                            old_calculated_total_ticks=old_ticks, intended_total_ticks=new_ticks,
                            old_nominal_ms=old_ticks * 30, new_nominal_ms=new_ticks * 30))
    print(json.dumps(dict(tick_cycles=945001, clock_hz=31500000,
                         tick_ms=945001 / 31500000 * 1000,
                         old_context="isolated request; previous settled bank 4; source-derived loads, not recorded analog audio",
                         effects=results), indent=2))


if __name__ == "__main__":
    main()
