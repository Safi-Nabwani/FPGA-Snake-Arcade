#!/usr/bin/env python3
"""Validate the supplied snake assets without rewriting any artwork."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SUPPLIED = ROOT / "assets" / "jungle" / "snake_sprite_sets_supplied"
INSTALLED = ROOT / "RTL" / "mifs" / "snake_variants"
INSTALLED_NAMES = [
    "01_emerald_rgba9.mif",
    "02_guardian_rgba9.mif",
    "03_viper_rgba9.mif",
    "04_mystical_rgba9.mif",
    "05_stone_rgba9.mif",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_mif(path: Path) -> list[int]:
    text = path.read_text(encoding="ascii")
    if not re.search(r"(?mi)^\s*WIDTH\s*=\s*9\s*;", text):
        raise ValueError(f"{path}: WIDTH is not 9")
    if not re.search(r"(?mi)^\s*DEPTH\s*=\s*8064\s*;", text):
        raise ValueError(f"{path}: DEPTH is not 8064")
    if not re.search(r"(?mi)^\s*ADDRESS_RADIX\s*=\s*HEX\s*;", text):
        raise ValueError(f"{path}: address radix is not HEX")
    if not re.search(r"(?mi)^\s*DATA_RADIX\s*=\s*HEX\s*;", text):
        raise ValueError(f"{path}: data radix is not HEX")

    words: list[int | None] = [None] * 8064
    for address_text, value_text in re.findall(
        r"(?mi)^\s*([0-9a-f]+)\s*:\s*([0-9a-f]+)\s*;", text
    ):
        address = int(address_text, 16)
        value = int(value_text, 16)
        if not 0 <= address < 8064:
            raise ValueError(f"{path}: address {address} is out of range")
        if not 0 <= value < 512:
            raise ValueError(f"{path}: word {value} is wider than 9 bits")
        if words[address] is not None:
            raise ValueError(f"{path}: duplicate address {address}")
        words[address] = value
    missing = [i for i, word in enumerate(words) if word is None]
    if missing:
        raise ValueError(f"{path}: {len(missing)} addresses are missing")
    return [int(word) for word in words]


def rgb332(red: int, green: int, blue: int) -> int:
    return ((red >> 5) << 5) | ((green >> 5) << 2) | (blue >> 6)


def validate(output: Path | None, variant_ids: set[int] | None = None) -> dict:
    manifest = json.loads((SUPPLIED / "manifest.json").read_text(encoding="utf-8"))
    sprite_order = manifest["sprite_order"]
    if len(sprite_order) != 14:
        raise ValueError("manifest does not define 14 sprites")

    result = {
        "sprite_order": sprite_order,
        "rom_interface": {
            "width": 9,
            "depth": 8064,
            "address": "sprite_index*576 + y*24 + x",
            "bit_8": "opacity",
            "bits_7_0": "RGB332",
        },
        "variants": [],
    }

    for index, design in enumerate(manifest["designs"]):
        variant_id = index + 1
        if variant_ids is not None and variant_id not in variant_ids:
            continue
        source_mif = SUPPLIED / design["subdir"] / "snake_rgba9.mif"
        installed_mif = INSTALLED / INSTALLED_NAMES[index]
        source_hash = sha256(source_mif)
        installed_hash = sha256(installed_mif)
        if source_hash != design["mif_sha256"]:
            raise ValueError(f"{design['concept']}: source MIF hash mismatch")
        if installed_mif.read_bytes() != source_mif.read_bytes():
            raise ValueError(f"{design['concept']}: installed MIF is not byte-identical")

        words = parse_mif(installed_mif)
        counts: dict[str, int] = {}
        for sprite_index, sprite_name in enumerate(sprite_order):
            png_path = SUPPLIED / design["subdir"] / f"{sprite_name}.png"
            image = Image.open(png_path).convert("RGBA")
            if image.size != (24, 24):
                raise ValueError(f"{png_path}: expected 24x24")
            opaque = 0
            for pixel_index, (red, green, blue, alpha) in enumerate(
                image.get_flattened_data()
            ):
                if alpha not in (0, 255):
                    raise ValueError(f"{png_path}: alpha is not binary")
                word = words[sprite_index * 576 + pixel_index]
                expected = ((1 if alpha else 0) << 8) | rgb332(red, green, blue)
                if word != expected:
                    raise ValueError(
                        f"{png_path}: MIF mismatch at pixel {pixel_index}: "
                        f"{word:03X} != {expected:03X}"
                    )
                opaque += int(alpha == 255)
            manifest_count = design["opaque_pixels_per_sprite"][sprite_name]
            if opaque != manifest_count:
                raise ValueError(
                    f"{png_path}: opaque count {opaque} != manifest {manifest_count}"
                )
            counts[sprite_name] = opaque

        result["variants"].append(
            {
                "id": variant_id,
                "concept": design["concept"],
                "source_mif_sha256": source_hash,
                "installed_mif_sha256": installed_hash,
                "byte_identical": True,
                "png_pixels_match_mif": True,
                "opaque_pixels_per_sprite": counts,
            }
        )

    if output is not None:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--variant",
        type=int,
        choices=range(1, 6),
        action="append",
        help="validate only the selected variant id; may be repeated",
    )
    args = parser.parse_args()
    selected = set(args.variant) if args.variant else None
    result = validate(args.output, selected)
    print(
        f"SNAKE_ASSET_VALIDATION_PASS variants={len(result['variants'])} "
        "sprites_per_variant=14 pixels_per_sprite=576"
    )


if __name__ == "__main__":
    main()
