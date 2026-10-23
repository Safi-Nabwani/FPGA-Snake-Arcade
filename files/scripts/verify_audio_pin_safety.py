"""Fail if internal debug outputs can drive real board pins, especially AG30.

Usage: python -B scripts/verify_audio_pin_safety.py path/to/Lab1Demo.pin
The six active codec pins must remain exactly as originally assigned.
"""
import argparse
import json
import re
from pathlib import Path

EXPECTED = {"AUDOUT[4]": ("AF29", "output"), "AUDOUT[5]": ("AH30", "output"),
            "AUDOUT[6]": ("Y24", "output"), "AUDOUT[7]": ("Y23", "output"),
            "AUDIN[1]": ("AH29", "input"), "AUDIN[2]": ("AF30", "input")}


def read_rows(path):
    if path.suffix.lower() == '.json':
        return json.loads(path.read_text())['rows']
    rows = []
    for line in path.read_text().splitlines():
        fields = [field.strip() for field in line.split(":")]
        if len(fields) >= 7:
            rows.append(fields)
    return rows


def physical(row):
    return bool(re.fullmatch(r"[A-Z]{1,2}\d+", row[1]))


def debug(name):
    return name == "borderDR" or name.startswith("BG_RGB[")


def verify(path, compare=None):
    records = read_rows(path)
    rows = {row[0]: row for row in records}
    failures = []
    for name, (pin, direction) in EXPECTED.items():
        row = rows.get(name)
        if not row or (row[1], row[2]) != (pin, direction):
            failures.append(f"Active codec pin changed: {name}: {row}")
    for row in records:
        name = row[0]
        if not physical(row):
            continue
        if debug(name):
            if row[2] in {"input", "output", "bidir"}:
                failures.append(f"Internal debug signal drives real package pin: {name} on {row[1]}")
        if row[1] == "AG30":
            if name != "RESERVED_INPUT_WITH_WEAK_PULLUP" or row[2] in {"output", "bidir"}:
                failures.append(f"Codec DACLRCK AG30 is not a reserved input: {row}")
        if row[2] in {"input", "output", "bidir"} and row[6] == "N":
            failures.append(f"Unconstrained physical design port: {name} on {row[1]}")
    if not any(row[1] == "AG30" for row in records):
        failures.append("AG30 is missing from pin report")
    if compare:
        def intended(data):
            return {row[0]: tuple(row[1:4]) for row in data if physical(row)
                    and row[2] in {"input", "output", "bidir"} and not debug(row[0])}
        if intended(read_rows(compare)) != intended(records):
            failures.append("An intended non-debug physical port changed pin/direction/I/O standard")
    if failures:
        raise SystemExit("AUDIO_PIN_SAFETY_FAIL\n" + "\n".join(failures))
    print(f"AUDIO_PIN_SAFETY_PASS {path}: no physical debug ports; AG30 input; all six codec pins unchanged")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pin_report", type=Path)
    parser.add_argument("--compare", type=Path)
    args = parser.parse_args()
    verify(args.pin_report, args.compare)
