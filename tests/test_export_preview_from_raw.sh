#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
INPUT_PATH="$TMP_DIR/biased_nv12.yuv"
OUTPUT_PATH="$TMP_DIR/corrected.ppm"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

python3 - <<'PY' "$INPUT_PATH"
from pathlib import Path
import numpy as np
import sys

path = Path(sys.argv[1])
w, h = 8, 8
y = np.full((h, w), 128, dtype=np.uint8)
uv = np.zeros((h // 2, w // 2, 2), dtype=np.uint8)
uv[:, :, 0] = 226
uv[:, :, 1] = 32
path.write_bytes(y.tobytes() + uv.tobytes())
PY

python3 "$REPO_ROOT/scripts/export_preview_from_raw.py" \
  --input "$INPUT_PATH" \
  --output "$OUTPUT_PATH" \
  --width 8 \
  --height 8 \
  --pixfmt NV12

python3 - <<'PY' "$OUTPUT_PATH"
from pathlib import Path
import numpy as np
import sys

path = Path(sys.argv[1])
raw = path.read_bytes()
header, payload = raw.split(b"\n255\n", 1)
if not header.startswith(b"P6\n8 8"):
    raise SystemExit("[FAIL] Unexpected PPM header")

rgb = np.frombuffer(payload, dtype=np.uint8).reshape(8, 8, 3)
means = rgb.reshape(-1, 3).mean(axis=0)
delta_rg = abs(float(means[0]) - float(means[1]))
delta_bg = abs(float(means[2]) - float(means[1]))
if delta_rg > 10 or delta_bg > 10:
    raise SystemExit(f"[FAIL] Corrected RGB means still too far apart: {means}")
print("PASS: export_preview_from_raw helper corrected biased NV12 preview.")
PY
