"""PREVIEW ONLY: native RGB332 floor conversion, fixed map and exact asset mockup.

Run with the bundled Python/Pillow runtime. Writes ONLY inside this directory.
Retained AI sources are inputs; regeneration does not require image generation.
"""
from pathlib import Path
import collections
import hashlib
import json
import random
import re
import sys

from PIL import Image, ImageDraw, ImageEnhance

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from build_jungle_assets import parse_mif, rgb

NAMES = ["ancient_stone", "mossy_stone", "cracked_stone", "engraved_stone"]
PALETTE = [0x00, 0x24, 0x25, 0x49, 0x6D, 0x28, 0x48, 0x4C]
SEED = 20261011


def mif(name, transparent=True):
    width, depth, codes = parse_mif((ROOT / "RTL/mifs" / (name + ".mif")).read_text())
    assert (width, depth) == (8, 576)
    result = Image.new("RGBA", (24, 24))
    result.putdata([(*rgb(v), 0 if transparent and v == 255 else 255) for v in codes])
    return result


def convert(name):
    # No procedural paint, dithering, smoothing or invented high-resolution detail.
    # Modest contrast expansion exposes the source's clustered relief to RGB332.
    source = Image.open(OUT / "source" / (name + ".png")).convert("RGB")
    native = source.resize((24, 24), Image.Resampling.NEAREST)
    native = ImageEnhance.Contrast(native).enhance(2.40 if name == "ancient_stone" else 1.20)
    pixels = list(native.get_flattened_data())
    candidates = [0x24, 0x25, 0x49, 0x6D] if name == "ancient_stone" else PALETTE
    if name == "mossy_stone":
        candidates = [c for c in candidates if c != 0x00]
    codes = [min(candidates, key=lambda c: sum((a-b)**2 for a, b in zip(p, rgb(c)))) for p in pixels]
    tile = Image.new("RGB", (24, 24))
    tile.putdata([rgb(v) for v in codes])
    tile.save(OUT / (name + "_24.png"))
    assert tile.size == (24, 24) and set(tile.get_flattened_data()) <= {rgb(c) for c in PALETTE}
    assert len(set(codes)) >= 3
    return tile, collections.Counter(codes)


def map_penalty(grid):
    penalty = 0
    for y in range(18):
        for x in range(20):
            v = grid[y*20+x]
            if x < 17 and all(grid[y*20+x+k] == v for k in range(4)):
                penalty += 5
            if y < 15 and all(grid[(y+k)*20+x] == v for k in range(4)):
                penalty += 5
            if x < 19 and y < 17 and v == grid[y*20+x+1] == grid[(y+1)*20+x] == grid[(y+1)*20+x+1]:
                penalty += 5
            # Suppress regular alternation while permitting natural short clusters.
            if x < 15 and grid[y*20+x:y*20+x+6] == [v, grid[y*20+x+1]]*3:
                penalty += 2
            if y < 13 and [grid[(y+k)*20+x] for k in range(6)] == [v, grid[(y+1)*20+x]]*3:
                penalty += 2
    return penalty


def fixed_map(blocked):
    rng = random.Random(SEED)
    visible = [i for i in range(360) if (i % 20, i // 20) not in blocked]
    hidden = [i for i in range(360) if i not in visible]
    grid = [None]*360
    # Exact whole-grid 45/25/20/10; nearest integer mix on 330 walkable cells.
    for indices, counts in [(visible, [149, 82, 66, 33]), (hidden, [13, 8, 6, 3])]:
        values = [v for v, count in enumerate(counts) for _ in range(count)]
        rng.shuffle(values)
        for i, v in zip(indices, values):
            grid[i] = v
    score = map_penalty(grid)
    swaps = 0
    for _ in range(20000):
        if score == 0:
            break
        indices = visible if rng.random() < .9 else hidden
        a, b = rng.sample(indices, 2)
        if grid[a] == grid[b]:
            continue
        grid[a], grid[b] = grid[b], grid[a]
        trial = map_penalty(grid)
        if trial <= score:
            score = trial
            swaps += 1
        else:
            grid[a], grid[b] = grid[b], grid[a]
    assert score == 0, "Fixed-map pattern checks failed"
    assert collections.Counter(grid) == {0: 162, 1: 90, 2: 72, 3: 36}
    rotations = [rng.randrange(4) for _ in range(360)]
    return grid, rotations, swaps


def hud(scene):
    draw = ImageDraw.Draw(scene)
    draw.rectangle((8, 24, 127, 455), fill=rgb(0x04))
    for rect in [(8, 24, 9, 455), (126, 24, 127, 455), (8, 24, 127, 25),
                 (8, 454, 127, 455), (8, 100, 127, 100), (8, 192, 127, 192)]:
        draw.rectangle(rect, fill=rgb(0x8D))
    labels = (ROOT / "RTL/VGA/hud_labels.sv").read_text()
    glyphs = {letter: bits.replace("_", "") for letter, bits in
              re.findall(r'"(.)": glyph = 35\x27b([01_]+)', labels)}
    for text, oy, color in [("SCORE", 40, 0xF9), ("HIGH", 112, 0xF9), ("SCORE", 128, 0xF9),
                            ("RELICS", 208, 0xF9), ("RUBY", 240, 0xED),
                            ("SAPPHIRE", 308, 0x57), ("CURSED", 376, 0xB3)]:
        for i, letter in enumerate(text):
            for bit, on in enumerate(glyphs[letter]):
                if on == "1":
                    x, y = 16+i*12+(bit % 5)*2, oy+(bit // 5)*2
                    draw.rectangle((x, y, x+1, y+1), fill=rgb(color))
    width, depth, font = parse_mif((ROOT / "RTL/mifs/numbers_new_font.mif").read_text())
    assert (width, depth) == (1, 8192)
    for text, ox, oy, color in [("12", 48, 64, 0xD9), ("19", 48, 148, 0xF9),
                               ("012", 40, 260, 0xED), ("000", 40, 328, 0x57),
                               ("000", 40, 396, 0xB3)]:
        for i, digit in enumerate(text):
            for y in range(32):
                for x in range(16):
                    if font[int(digit)*512+y*16+x]:
                        scene.putpixel((ox+i*16+x, oy+y), rgb(color))


def main():
    active = json.loads((ROOT / "assets/jungle/implemented/arena_map.json").read_text())
    blocked = {tuple(cell) for cell in active["blocked"]}
    assert len(blocked) == 30
    assert {(i % 20, i // 20) for i, d in enumerate(active["descriptor"]) if (d & 7) >= 4} == blocked
    tiles, usage = zip(*(convert(name) for name in NAMES))
    grid, rotations, swaps = fixed_map(blocked)
    sheet = Image.new("RGB", (480, 152), rgb(0x04))
    draw = ImageDraw.Draw(sheet)
    for i, tile in enumerate(tiles):
        sheet.paste(tile.resize((96, 96), Image.Resampling.NEAREST), (i*120+12, 8))
        draw.text((i*120+8, 110), NAMES[i].replace("_", " "), fill=rgb(0xD9))
        draw.text((i*120+8, 130), "24x24 / 4x nearest", fill=rgb(0x6D))
    sheet.save(OUT / "tile_comparison_4x.png")
    scene = Image.new("RGB", (640, 480), rgb(0x04))
    hud(scene)
    rot = [None, Image.Transpose.ROTATE_270, Image.Transpose.ROTATE_180, Image.Transpose.ROTATE_90]
    ruins = {4: mif("rock_tile_24"), 5: mif("ruin_wall_24"), 6: mif("ruin_pillar_24")}
    for i, variant in enumerate(grid):
        x, y = 144+(i % 20)*24, 24+(i // 20)*24
        tile = tiles[variant]
        if rotations[i]:
            tile = tile.transpose(rot[rotations[i]])
        scene.paste(tile, (x, y))
        descriptor = active["descriptor"][i]
        if (descriptor & 7) >= 4:
            # Active obstacle pixels and descriptor rotations are read verbatim.
            obstacle = ruins[descriptor & 7]
            turn = (descriptor >> 3) & 3
            if turn:
                obstacle = obstacle.transpose(rot[turn])
            scene.paste(obstacle, (x, y), obstacle)
            assert scene.crop((x, y, x+24, y+24)).convert("RGBA").tobytes() == obstacle.tobytes()
    body = [(10,10),(10,11),(10,12),(10,13),(10,14),(11,14),(12,14),(13,14),
            (13,13),(13,12),(13,11),(13,10),(13,9),(13,8),(13,7),(13,6)]
    objects = [("snake_body_24", x, y) for x, y in body]
    objects += [("snake_head_24",10,9), ("red_apple_24",7,3),
                ("blue_apple_24",5,10), ("black_apple_24",12,6)]
    assert all((x, y) not in blocked for _, x, y in objects)
    assert len({(x, y) for _, x, y in objects}) == len(objects)
    for name, x, y in objects:
        sprite = mif(name)
        scene.paste(sprite, (144+x*24, 24+y*24), sprite)
    scene.save(OUT / "gameplay_mockup_640x480.png")
    diagram = Image.new("RGB", (640, 480), rgb(0x04))
    draw = ImageDraw.Draw(diagram)
    colors = [0x49, 0x4C, 0x6D, 0x91]
    for i, variant in enumerate(grid):
        x, y = 144+(i % 20)*24, 24+(i // 20)*24
        draw.rectangle((x, y, x+23, y+23), fill=rgb(colors[variant]))
        draw.text((x+8, y+7), str(variant+1), fill=rgb(0x00))
        if (i % 20, i // 20) in blocked:
            draw.rectangle((x, y, x+23, y+23), outline=rgb(0xD9), width=2)
            draw.line((x+2, y+2, x+21, y+21), fill=rgb(0xD9))
    for i, (name, count) in enumerate(zip(NAMES, [162,90,72,36])):
        y = 48+i*64
        draw.rectangle((8, y, 24, y+16), fill=rgb(colors[i]))
        draw.text((30, y+3), str(i+1), fill=rgb(0xD9))
        draw.text((8, y+23), name.replace("_", " "), fill=rgb(0xD9))
        draw.text((8, y+39), f"{count} / {count/360:.0%}", fill=rgb(0xD9))
    draw.text((8, 344), "Gold X: obstacle", fill=rgb(0xD9))
    draw.text((8, 364), "Seed 20261011", fill=rgb(0xD9))
    diagram.save(OUT / "floor_distribution_map.png")
    payload = {"preview_only": True, "seed": SEED, "columns": 20, "rows": 18,
               "variant_names": NAMES, "variants_row_major": grid, "clockwise_quarter_turns": rotations,
               "whole_grid_counts": [162,90,72,36], "visible_walkable_counts": [149,82,66,33],
               "unchanged_obstacles": sorted(blocked), "pattern_penalty": 0, "accepted_swaps": swaps}
    (OUT / "floor_selection_map.json").write_text(json.dumps(payload, indent=2)+"\n")
    verification = {"tile_size": [24,24], "scene_size": list(scene.size), "palette_codes": [f"{c:02X}" for c in PALETTE],
                    "tile_color_counts": {name: {f"{c:02X}": n for c,n in counts.items()} for name, counts in zip(NAMES,usage)},
                    "obstacles": "all 30 exact MIF/rotation pixel crops match",
                    "map_patterns": "no uniform 2x2, four-cell straight runs, or six-cell AB alternation",
                    "protected_input_hashes": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                               for p in sorted((ROOT / "RTL").rglob("*")) if p.is_file()}}
    (OUT / "verification.json").write_text(json.dumps(verification, indent=2)+"\n")
    print("PREVIEW_PASS: 4 native RGB332 tiles, exact 360-cell quotas, pattern checks, 30 unchanged obstacle crops, exact HUD glyphs/MIF.")


if __name__ == "__main__":
    main()
