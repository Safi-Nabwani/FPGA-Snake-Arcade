"""V4 integration checks and MIF-only previews. Never creates/edits artwork MIFs.

--header prints the deterministic selection table for apply_patch installation.
--fixtures copies actual active ROM data and frozen historical collision RTL.
--preview composes existing MIF pixels, without quantization or recoloring.
--floor-archive/--obstacle-archive check complete authoritative ZIP byte equality.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import random
import re
import subprocess
import sys
import zipfile
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
from build_jungle_assets import parse_mif, rgb
from supplied_floor_tiles import hud, load

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/jungle/v4_implemented'
FLOORS = [n + '_24x24_rgb332' for n in
          ['ancient_stone', 'mossy_stone', 'cracked_stone', 'engraved_stone']]
OBSTACLES = [n + '_floor_match_v4_24' for n in
             ['rock_tile', 'ruin_wall', 'ruin_pillar']]
NAMES = FLOORS + OBSTACLES
SEED = 20261014
COUNTS = [270, 43, 36, 11]
VISIBLE_COUNTS = [248, 39, 33, 10]
EXPECTED_SHA256 = {
    'ancient_stone_24x24_rgb332': 'aeff526305e9dcffb6e1b3f83480a3c2b1ceb607b6d41a771c62c575d5fd48b6',
    'mossy_stone_24x24_rgb332': '8e6fd33fbbadb54a38bcfa7c95306560aae3341beca513c2c73f6ea0c4ee5080',
    'cracked_stone_24x24_rgb332': 'f7e6d001ccf63a8a59d8e8ba6d2a5e2a6134f686c7806421211c273b97512e60',
    'engraved_stone_24x24_rgb332': '77e661e7e1f1244b2f9e6a69870a91c7bf4ee66edff5b2fd02d82d3cbab3e8ef',
    'rock_tile_floor_match_v4_24': '18b4ed22893f056b6fd1bc501d56af8af3ebe9f9cb0d687d2ec45aedc3183dc9',
    'ruin_wall_floor_match_v4_24': 'a38e5aa4b338ee60a4be7dcc812086242a3263053c8a74cf22782bf4ac7777ad',
    'ruin_pillar_floor_match_v4_24': 'ac9d23a9a952a6fd97c2b5ebd3701c676854069abb2200a882a31d614c729309',
}


def check_build(output):
    """Read existing reports only: no compiler launch or settings modifications."""
    baseline = ROOT / 'db/phase3a3_build/source/output_files'

    def reports(folder):
        result = {'stages': {}}
        for stage in ['map', 'fit', 'sta', 'asm']:
            text = (folder / ('Lab1Demo.' + stage + '.rpt')).read_text()
            totals = re.search(r'was successful\.\s*(\d+) errors,\s*(\d+) warnings', text)
            assert totals and int(totals[1]) == 0, 'Failed/incomplete ' + stage
            codes = Counter(re.findall(r'^\s*(?:Critical )?Warning(?: \((\d+)\))?:', text, re.M))
            result['stages'][stage] = dict(errors=int(totals[1]), warnings=int(totals[2]), warning_codes=dict(codes))
        text = (folder / 'Lab1Demo.sta.summary').read_text()
        timing = re.findall(r"Type\s*:\s*(.+?)\s+'([^']+)'\s*\nSlack\s*:\s*([-+\d.]+)\s*\nTNS\s*:\s*([-+\d.]+)", text)
        assert len(timing) == 40 and all(float(s) > 0 and float(t) == 0 for _,_,s,t in timing), 'Timing checks failed'
        result['timing'] = [dict(check=c, clock=k, slack=float(s), tns=float(t)) for c,k,s,t in timing]
        result['worst_setup'] = min(float(s) for c,_,s,_ in timing if c.endswith('Setup'))
        result['worst_hold'] = min(float(s) for c,_,s,_ in timing if c.endswith('Hold'))
        summary = (folder / 'Lab1Demo.fit.summary').read_text()
        result['resources'] = dict(re.findall(r'^(Logic utilization \(in ALMs\)|Total registers|Total pins|Total block memory bits|Total RAM Blocks|Total DSP Blocks|Total PLLs)\s*:\s*(.+)$', summary, re.M))
        assert len(result['resources']) == 7
        return result

    data = dict(baseline=reports(baseline), v4=reports(output))
    print(json.dumps(data, indent=2))
    return data


def floor_map(blocked):
    """Quota-preserving seeded shuffle; remove solid 3x3s and 7-cell stripes.

    At 75% base stone, short same-kind runs/2x2 groups are natural and necessary.
    Accent quotas apply separately to visible cells and cells hidden by obstacles.
    """
    rng = random.Random(SEED)
    groups = [[i for i in range(360) if ((i % 20, i // 20) in blocked) == hidden]
              for hidden in [False, True]]
    g = [None] * 360
    for indices, quotas in zip(groups, [VISIBLE_COUNTS, [22, 4, 3, 1]]):
        values = [v for v, count in enumerate(quotas) for _ in range(count)]
        rng.shuffle(values)
        for i, v in zip(indices, values):
            g[i] = v
    windows = []
    for y in range(18):
        for x in range(20):
            if x < 14:
                windows.append(([y * 20 + x + k for k in range(7)], 0))
            if y < 12:
                windows.append(([(y + k) * 20 + x for k in range(7)], 0))
            if x < 18 and y < 16:
                windows.append(([(y + dy) * 20 + x + dx for dy in range(3) for dx in range(3)], 0))
            if x < 15:
                windows.append(([y * 20 + x + k for k in range(6)], 1))
            if y < 13:
                windows.append(([(y + k) * 20 + x for k in range(6)], 1))
    touching = [set() for _ in range(360)]
    for w, (indices, _) in enumerate(windows):
        for i in indices:
            touching[i].add(w)

    def bad(w):
        indices, alternating = windows[w]
        v = [g[i] for i in indices]
        if alternating:
            return int(v[0] != v[1] and v == v[:2] * 3)
        return 5 * int(len(set(v)) == 1)

    penalties = [bad(w) for w in range(len(windows))]
    score = sum(penalties)
    for _ in range(100000):
        if score == 0:
            break
        a, b = rng.sample(groups[0] if rng.random() < .92 else groups[1], 2)
        if g[a] == g[b]:
            continue
        affected = touching[a] | touching[b]
        before = sum(penalties[w] for w in affected)
        g[a], g[b] = g[b], g[a]
        trial = {w: bad(w) for w in affected}
        after = sum(trial.values())
        if after <= before:
            score += after - before
            for w, value in trial.items():
                penalties[w] = value
        else:
            g[a], g[b] = g[b], g[a]
    assert score == 0, 'Distribution constraints not met'
    assert [Counter(g)[i] for i in range(4)] == COUNTS
    assert [Counter(g[i] for i in groups[0])[v] for v in range(4)] == VISIBLE_COUNTS
    assert len({tuple(g[y * 20:y * 20 + 20]) for y in range(18)}) == 18
    assert len({tuple(g[y * 20 + x] for y in range(18)) for x in range(20)}) == 20
    assert g != list(reversed(g))
    assert g != [g[y * 20 + 19 - x] for y in range(18) for x in range(20)]
    assert g != [g[(17 - y) * 20 + x] for y in range(18) for x in range(20)]
    return g


def header(g):
    lines = ['// Supplied approved V4 floor selection; frozen obstacles remain in jungle_map.svh.',
             '// Seed 20261014; 270/43/36/11 cells. No supplied pixel changes or floor rotation.',
             'function automatic [1:0] jungleFloorTile(input logic [4:0] x, y);',
             '    logic [39:0] row;', '    begin', '        case (y)']
    for y in range(18):
        row = sum(g[y * 20 + x] << (2 * x) for x in range(20))
        lines.append(f"        5'd{y}: row = 40'h{row:010X};")
    lines += ["        default: row = 40'd0;", '        endcase',
              "        jungleFloorTile = (x < 20 && y < 18) ? ((row >> (x * 2)) & 40'h3) : 2'd0;",
              '    end', 'endfunction', '']
    return '\n'.join(lines)


def fixture_data(merged):
    fixture = ROOT / 'db/jungle_implementation_fixture'
    fixture.mkdir(parents=True, exist_ok=True)
    sprites = ['snake_head_24', 'snake_body_24', 'red_apple_24', 'blue_apple_24', 'black_apple_24']
    for name in NAMES + sprites:
        codes, _ = load(name)
        (fixture / (name + '.hex')).write_text(''.join(f'{v:02x}\n' for v in codes))
    (fixture / 'map.hex').write_text(''.join(f'{v:02x}\n' for v in merged))
    # Frozen reference files are copied from Git, not regenerated from artwork.
    for filename, module in [('headBitMap.sv', 'headBitMap'), ('AppleBitMap.sv', 'AppleBitMap'), ('snake_body.sv', 'snake_body')]:
        raw = subprocess.check_output(['git', 'show', '19ae76c:RTL/VGA/' + filename], cwd=ROOT).decode().replace('\r\n', '\n')
        raw = raw.replace('module ' + module + ' (', 'module legacy_' + module + ' (')
        for name in sprites:
            raw = raw.replace('RTL/mifs/' + name + '.mif', 'db/jungle_implementation_fixture/legacy_' + name + '.mif')
        (fixture / ('legacy_' + filename)).write_text(raw)
    for name in sprites:
        raw = subprocess.check_output(['git', 'show', '19ae76c:RTL/mifs/' + name + '.mif'], cwd=ROOT)
        (fixture / ('legacy_' + name + '.mif')).write_bytes(raw)


def preview(merged, blocked, g):
    OUT.mkdir(parents=True, exist_ok=True)
    scene = Image.new('RGB', (640, 480), rgb(4))
    hud(scene)
    tiles = [load(n)[1] for n in NAMES]
    rot = [None, Image.Transpose.ROTATE_270, Image.Transpose.ROTATE_180, Image.Transpose.ROTATE_90]
    seen = Counter()
    for i, desc in enumerate(merged):
        tile = tiles[desc & 7]
        if desc >> 3:
            tile = tile.transpose(rot[desc >> 3])
        x, y = 144 + (i % 20) * 24, 24 + (i // 20) * 24
        scene.paste(tile, (x, y), tile)
        assert scene.crop((x, y, x + 24, y + 24)).tobytes() == tile.convert('RGB').tobytes()
        seen[desc & 7] += 1
    assert set(seen) == set(range(7)), 'All seven supplied assets must appear'
    scene.save(OUT / 'arena_and_hud_640x480.png')
    pose = [(10,10),(10,11),(10,12),(10,13),(10,14),(11,14),(12,14),(13,14),
            (13,13),(13,12),(13,11),(13,10),(13,9),(13,8),(13,7),(13,6)]
    objects = [('snake_body_24', x, y) for x, y in pose] + [
        ('snake_head_24',10,9), ('red_apple_24',7,3), ('blue_apple_24',5,10), ('black_apple_24',12,6)]
    for name, x, y in objects:
        assert (x, y) not in blocked
        _, im = load(name)
        scene.paste(im, (144 + x * 24, 24 + y * 24), im)
    scene.save(OUT / 'full_scene_640x480.png')
    comparison = Image.new('RGB', (24 * 7, 24), rgb(4))
    for i, tile in enumerate(tiles):
        comparison.paste(tile, (24 * i, 0), tile)
    comparison.resize((24 * 7 * 4, 96), Image.Resampling.NEAREST).save(OUT / 'supplied_assets_4x.png')
    selection = Image.new('RGB', (480, 432))
    draw = ImageDraw.Draw(selection)
    palette = ['#666666', '#496b35', '#a88455', '#827198']
    for i, kind in enumerate(g):
        x, y = (i % 20) * 24, (i // 20) * 24
        draw.rectangle((x, y, x + 23, y + 23), fill=palette[kind], outline='#242424')
        draw.text((x + 8, y + 6), 'AMCE'[kind], fill='white')
        if (i % 20, i // 20) in blocked:
            draw.line((x, y, x + 23, y + 23), fill='black', width=2)
    selection.save(OUT / 'floor_selection_map.png')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--header', action='store_true')
    p.add_argument('--fixtures', action='store_true')
    p.add_argument('--preview', action='store_true')
    p.add_argument('--floor-archive', type=Path)
    p.add_argument('--obstacle-archive', type=Path)
    p.add_argument('--git-index', action='store_true')
    p.add_argument('--build-results', type=Path)
    args = p.parse_args()
    old = json.loads((ROOT / 'assets/jungle/implemented/arena_map.json').read_text())
    blocked = {tuple(c) for c in old['blocked']}
    assert len(blocked) == 30
    g = floor_map(blocked)
    if args.header:
        print(header(g))
        return
    assert (ROOT / 'RTL/VGA/jungle_floor_map.svh').read_text() == header(g)
    records = {}
    manifest = OUT / 'asset_verification.json'
    prior = json.loads(manifest.read_text()) if manifest.exists() else None
    for name in NAMES:
        path = ROOT / 'RTL/mifs' / (name + '.mif')
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == EXPECTED_SHA256[name], name + ' supplied bytes changed'
        width, depth, codes = parse_mif(raw.decode())
        assert (width, depth) == (8, 576) and 255 not in codes
        # Directly decode data; no PNG-to-MIF conversion path exists.
        _, im = load(name)
        archive = args.floor_archive if name in FLOORS else args.obstacle_archive
        if archive:
            with zipfile.ZipFile(archive) as z:
                assert raw == z.read(name + '.mif'), name + ' differs from authoritative ZIP'
                source = Image.open(io.BytesIO(z.read(name + '.png'))).convert('RGBA')
                assert source.size == (24, 24) and source.getextrema()[3] == (255, 255)
                assert max(abs(a-b) for p0,p1 in zip(source.get_flattened_data(), im.get_flattened_data())
                           for a,b in zip(p0[:3],p1[:3])) <= 1, name + ' PNG/address mismatch'
        else:
            assert prior and prior[name]['sha256'] == hashlib.sha256(raw).hexdigest(), 'Supply authoritative archives on first run'
        if args.git_index:
            assert raw == subprocess.check_output(['git','show',':RTL/mifs/' + name + '.mif'], cwd=ROOT)
        records[name] = dict(sha256=hashlib.sha256(raw).hexdigest(), words=576, colors=len(set(codes)), transparent_pixels=0)
    merged = [d if (d & 7) >= 4 else g[i] for i, d in enumerate(old['descriptor'])]
    assert [(i, d) for i, d in enumerate(merged) if (d & 7) >= 4] == [
        (i, d) for i, d in enumerate(old['descriptor']) if (d & 7) >= 4]
    assert subprocess.check_output(['git','show','d6e230f:RTL/VGA/jungle_map.svh'],cwd=ROOT).replace(b'\r\n',b'\n') == (
        ROOT / 'RTL/VGA/jungle_map.svh').read_bytes().replace(b'\r\n',b'\n')
    if args.fixtures:
        fixture_data(merged)
    if args.preview:
        preview(merged, blocked, g)
        manifest.write_text(json.dumps(records, indent=2) + '\n')
        (OUT / 'floor_selection_map.json').write_text(json.dumps(dict(seed=SEED, rows=18, columns=20,
            variants=g, counts=COUNTS, visible_counts=VISIBLE_COUNTS, blocked=old['blocked']),indent=2)+'\n')
    if args.build_results:
        check_build(args.build_results)
    print('V4_ASSETS_PASS: seven exact 8x576 RGB332 MIFs; no FF; 270/43/36/11 floor map; unchanged 30 obstacle descriptors; pipeline unchanged')


if __name__ == '__main__':
    main()
