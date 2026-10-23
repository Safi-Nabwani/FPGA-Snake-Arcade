"""Shared lossless MIF parsing and existing HUD preview helpers. Requires Pillow only for previews."""
import re

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

def rgb(code):
    """Nominal RGB332 preview expansion; no hardware pixel changes."""
    return ((code >> 5) * 255 // 7, ((code >> 2) & 7) * 255 // 7, (code & 3) * 255 // 3)

FIELDS = [('score',57,116,2,0xF9),('high_score',56,182,2,0xF9),
          ('ruby',64,273,3,0xED),('sapphire',64,317,3,0x57),('cursed',64,362,3,0xB3)]

def numbers(scene,font,values):
    result=scene.copy()
    for (name,x,y,digits,col),value in zip(FIELDS,values):
        assert len(value)==digits
        for i,letter in enumerate(value):
            for dy in range(18):
                for dx in range(16):
                    if font[int(letter,16)*512+(6+dy)*16+dx]:
                        result.putpixel((x+i*16+dx,y+dy),rgb(col))
    return result
