"""Reproducible RGB332 ROM conversion, mask preservation, and asset verification.

Requires Pillow. Run from any directory:
  python scripts/build_jungle_assets.py --capture-masks
  python scripts/build_jungle_assets.py --write
  python scripts/build_jungle_assets.py --check

AI artwork is retained in assets/jungle/source; generation is not deterministic.
Conversion of those retained inputs to MIF/PNG is deterministic. No RTL editing.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/jungle"
PREVIEW = ASSETS / "previews"
BASELINE = "1d8725a"
NAMES = {
    "grass_tile_24": "Mossy floor",
    "stone_tile_24": "Cracked floor",
    "rock_tile_24": "Temple obstacle",
    "snake_head_24": "Emerald head",
    "snake_body_24": "Emerald body",
    "red_apple_24": "Ruby relic",
    "blue_apple_24": "Sapphire relic",
    "black_apple_24": "Cursed relic",
}
SPRITES = [name for name in NAMES if "tile" not in name]


def parse_mif(text):
    text = re.sub(r"%.*?%", "", text, flags=re.S)
    text = re.sub(r"--[^\n]*", "", text)
    depth = int(re.search(r"DEPTH\s*=\s*(\d+)", text, re.I)[1])
    width = int(re.search(r"WIDTH\s*=\s*(\d+)", text, re.I)[1])
    bases = {"HEX": 16, "DEC": 10, "UNS": 10, "BIN": 2, "OCT": 8}
    address_base = bases[re.search(r"ADDRESS_RADIX\s*=\s*(\w+)", text, re.I)[1].upper()]
    data_base = bases[re.search(r"DATA_RADIX\s*=\s*(\w+)", text, re.I)[1].upper()]
    body = re.search(r"CONTENT\s+BEGIN(.*?)END\s*;", text, re.I | re.S)[1]
    values = [None] * depth
    for lo, hi, single, value in re.findall(
        r"(?:\[([0-9a-f]+)\s*\.\.\s*([0-9a-f]+)\]|([0-9a-f]+))\s*:\s*([0-9a-f]+)\s*;", body, re.I
    ):
        start, end = (int(lo, address_base), int(hi, address_base)) if lo else (int(single, address_base), int(single, address_base))
        val = int(value, data_base)
        assert 0 <= start <= end < depth and val < (1 << width)
        for address in range(start, end + 1):
            assert values[address] is None, "Duplicate MIF address"
            values[address] = val
    assert all(v is not None for v in values), "Incomplete MIF"
    return width, depth, values


def capture_masks():
    """One-time extraction from the approved pre-artwork commit; no ROM edits."""
    path = ASSETS / "collision_masks.json"
    if path.exists():
        raise RuntimeError("Masks already exist; refusing to overwrite collision reference")
    records = {}
    for name in NAMES:
        raw = subprocess.check_output(
            ["git", "show", f"{BASELINE}:RTL/mifs/{name}.mif"], cwd=ROOT
        )
        width, depth, values = parse_mif(raw.decode())
        assert (width, depth) == (8, 576)
        records[name] = {
            "rows": ["".join("0" if v == 255 else "1" for v in values[y*24:y*24+24]) for y in range(24)],
            "original_mif_sha256": hashlib.sha256(raw).hexdigest(),
        }
    ASSETS.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"baseline_commit": BASELINE, "assets": records}, indent=2) + "\n")


def rgb(code):
    """Nominal RGB332 preview expansion, NOT the DAC's unusual low-bit mapping."""
    return ((code >> 5) * 255 // 7, ((code >> 2) & 7) * 255 // 7, (code & 3) * 255 // 3)


PALETTE = [rgb(v) for v in range(255)]  # FF is exclusively transparent.


def encode(pixel, candidates=range(255)):
    return min(candidates, key=lambda v: sum((a-b)**2 for a, b in zip(pixel[:3], PALETTE[v])))


def convert(name, mask):
    image = Image.open(ASSETS / "source" / (name + ".png")).convert("RGBA")
    if name == "snake_head_24":
        # Generated face has snout at bottom. ROM requires snout at TOP (DIR_UP).
        image = image.transpose(Image.Transpose.ROTATE_180)
    floor = name in ("grass_tile_24", "stone_tile_24")
    image = image.resize((24, 24), Image.Resampling.BOX if floor else Image.Resampling.NEAREST)
    pixels = [image.getpixel((x,y)) for y in range(24) for x in range(24)]
    opaque = [i for i, pixel in enumerate(pixels) if pixel[3] >= 128]
    assert opaque, "Source image contains no opaque pixels"
    result = []
    for i, occupied in enumerate(mask):
        if occupied == "0":
            result.append(255)
            continue
        sample = pixels[i]
        if sample[3] < 128:
            # Extend nearest actual art pixel into the legacy collision silhouette.
            # Generated alpha never controls gameplay transparency.
            nearest = min(opaque, key=lambda j: (i % 24-j % 24)**2 + (i // 24-j // 24)**2)
            sample = pixels[nearest]
        # Constrained, muted floor palette reduces high-frequency noise at VGA scale.
        candidates = (0x24, 0x49, 0x6D, 0x6E, 0x28, 0x4C) if floor else range(255)
        result.append(encode(sample, candidates))
    assert "".join("0" if v == 255 else "1" for v in result) == mask
    return result


def mif_text(name, values):
    return (
        f"-- Temple of the Serpent: {NAMES[name]}. Generated by scripts/build_jungle_assets.py\n"
        "-- RGB332 R[7:5], G[4:2], B[1:0]; FF transparent; address=y*24+x.\n"
        "-- Original per-address collision/drawing mask is retained exactly.\n"
        "DEPTH = 576;\nWIDTH = 8;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT BEGIN\n"
        + "".join(f"{i:03X} : {v:02X};\n" for i, v in enumerate(values)) + "END;\n"
    )


def decoded(values):
    image = Image.new("RGBA", (24, 24))
    image.putdata([(*rgb(v), 0 if v == 255 else 255) for v in values])
    return image


def make_previews(converted):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (768, 416), "#101a16")
    draw = ImageDraw.Draw(sheet)
    images = {}
    for i, (name, values) in enumerate(converted.items()):
        image = decoded(values)
        images[name] = image
        image.save(PREVIEW / (name + ".png"))
        large = image.resize((144, 144), Image.Resampling.NEAREST)
        x, y = (i % 4)*192 + 24, (i // 4)*208 + 32
        sheet.paste(large, (x, y), large)
        draw.text((x, y+152), NAMES[name], fill="#dde5bc")
    sheet.save(PREVIEW / "asset_sheet.png")
    # Explicit ROM-address rotations used by the UNCHANGED headBitMap, not guessed directions.
    rotations = Image.new("RGB", (768, 208), "#101a16")
    draw = ImageDraw.Draw(rotations)
    values = converted["snake_head_24"]
    for i, direction in enumerate(("UP", "RIGHT", "DOWN", "LEFT")):
        pixels = []
        for y in range(24):
            for x in range(24):
                rx, ry = {"UP": (x,y), "RIGHT": (y,23-x), "DOWN": (23-x,23-y), "LEFT": (23-y,x)}[direction]
                pixels.append(values[ry*24+rx])
        image = decoded(pixels).resize((144,144), Image.Resampling.NEAREST)
        rotations.paste(image, (i*192+24,32), image)
        draw.text((i*192+24,184), direction + " (24x24 ROM)", fill="#dde5bc")
    rotations.save(PREVIEW / "head_rotations.png")
    # Arena-only assembly from actual RTL row constants, not a new obstacle/layout map.
    rtl = (ROOT / "RTL/VGA/back_ground_draw.sv").read_text()
    rows = dict((int(row), data.replace("_", "")) for row, data in re.findall(r"ARENA_ROW_(\d+)\s*=\s*40'b([01_]+)", rtl))
    assert len(rows) == 18
    arena = Image.new("RGB", (480,432))
    for y in range(18):
        for x in range(20):
            tile = int(rows[y][x*2:x*2+2],2)
            arena.paste(images[("grass_tile_24", "stone_tile_24", "rock_tile_24")[tile]], (x*24,y*24))
    # Illustrative trail only, NOT a simulation screenshot. Actual reset head is (10,9).
    for x, y in ((10,10), (10,11), (10,12), (11,12), (12,12)):
        arena.paste(images["snake_body_24"], (x*24,y*24), images["snake_body_24"])
    for name, x, y in (("snake_head_24",10,9), ("red_apple_24",7,3), ("blue_apple_24",5,10), ("black_apple_24",12,6)):
        arena.paste(images[name], (x*24,y*24), images[name])
    arena.save(PREVIEW / "arena_art_preview.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-masks", action="store_true")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.capture_masks:
        capture_masks()
        print("Captured immutable pre-artwork transparency masks")
        return
    if not (args.write or args.check):
        parser.error("Choose --write or --check")
    reference = json.loads((ASSETS / "collision_masks.json").read_text())
    converted = {}
    for name in NAMES:
        mask = "".join(reference["assets"][name]["rows"])
        assert len(mask) == 576 and set(mask) <= {"0", "1"}
        values = convert(name, mask)
        path = ROOT / "RTL/mifs" / (name + ".mif")
        expected = mif_text(name, values)
        if args.write:
            path.write_text(expected, encoding="ascii", newline="\n")
        assert path.read_text() == expected, f"Non-reproducible MIF: {path}"
        width, depth, actual = parse_mif(path.read_text())
        assert (width, depth, actual) == (8,576,values)
        assert "".join("0" if v == 255 else "1" for v in actual) == mask
        converted[name] = values
        print(f"{name}: 576 addresses; opaque={mask.count('1')}; FF mask identical; RGB332 PASS")
    if args.write:
        make_previews(converted)
        fixture = ROOT / "db/jungle_graphics_fixture"
        fixture.mkdir(parents=True, exist_ok=True)
        for name, values in converted.items():
            (fixture / (name + ".hex")).write_text("".join(f"{v:02x}\n" for v in values))
            mask = "".join(reference["assets"][name]["rows"])
            (fixture / (name + "_mask.hex")).write_text("\n".join(mask) + "\n")
    for name, values in converted.items():
        preview = Image.open(PREVIEW / (name + ".png"))
        expected_image = decoded(values)
        assert preview.size == (24,24) and preview.tobytes() == expected_image.tobytes()
    print("JUNGLE_ASSETS_PASS: deterministic MIFs, exact masks, preview round trips")


if __name__ == "__main__":
    main()
