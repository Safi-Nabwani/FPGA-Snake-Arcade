"""Extract/namespace fitted audio modules for read-only diagnostic simulation."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / "db/audio_noise_investigation/netlist/Lab1Demo.vo"
text = source.read_text()
start = text.index("module AUDIO (")
end = text.index("module back_ground_draw (")
audio = text[start:end]
names = re.findall(r"^module\s+(\w+)\s*\(", audio, re.M)
# Rename only declarations and instance types, never quoted MIF paths or nets.
pattern = r"^(module\s+)?(" + "|".join(map(re.escape, names)) + r")(?=\s)"
audio = re.sub(pattern, lambda m: (m[1] or "") + "noise_net_" + m[2], audio, flags=re.M)
destination = root / "db/audio_noise_investigation/audio_fitted.vo"
destination.write_text("`timescale 1ps/1ps\n" + audio)
print(f"Extracted {len(names)} unmodified fitted module bodies to {destination}")
