#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
SAMPLE_DIR="$REPO_ROOT/${SAMPLE_DIR:-samples/ov13855}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/test_ov13855_${TIMESTAMP}.log"

VIDEO_NODE="${VIDEO_NODE:-/dev/video23}"
RAW_VIDEO_NODE="${RAW_VIDEO_NODE:-/dev/video1}"
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1080}"
PIXEL_FORMAT="${PIXEL_FORMAT:-NV12}"
RAW_WIDTH="${RAW_WIDTH:-4224}"
RAW_HEIGHT="${RAW_HEIGHT:-3136}"
RAW_PIXEL_FORMAT="${RAW_PIXEL_FORMAT:-BG10}"
STREAM_SKIP="${STREAM_SKIP:-10}"
STABLE_TEST_FRAMES="${STABLE_TEST_FRAMES:-300}"

YUV_SAMPLE="$SAMPLE_DIR/ov13855_1920x1080_nv12.yuv"
JPG_SAMPLE="$SAMPLE_DIR/ov13855_1920x1080.jpg"
DMESG_BEFORE="$LOG_DIR/dmesg_before_${TIMESTAMP}.log"
DMESG_AFTER="$LOG_DIR/dmesg_after_${TIMESTAMP}.log"
DMESG_DELTA="$LOG_DIR/dmesg_delta_${TIMESTAMP}.log"
DMESG_ERRORS="$LOG_DIR/dmesg_errors_${TIMESTAMP}.log"
IGNORE_PATTERN='rkcif-mipi-lvds2|rkisp-vir1: rkisp_enum_frameintervals Not active sensor|vblank need >= 1000us'

mkdir -p "$LOG_DIR" "$SAMPLE_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Missing required command: $1"
    exit 1
  fi
}

section() {
  echo
  echo "===== $1 ====="
}

assert_nonempty_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "[ERROR] Expected non-empty file: $path"
    exit 1
  fi
}

require_cmd v4l2-ctl

section "Single Capture"
v4l2-ctl -d "$VIDEO_NODE" \
  --set-fmt-video=width="$WIDTH",height="$HEIGHT",pixelformat="$PIXEL_FORMAT" \
  --stream-mmap=4 \
  --stream-skip="$STREAM_SKIP" \
  --stream-count=1 \
  --stream-to="$YUV_SAMPLE" \
  --verbose
assert_nonempty_file "$YUV_SAMPLE"
ls -lh "$YUV_SAMPLE"

section "Sample Export"
if command -v gst-launch-1.0 >/dev/null 2>&1; then
  gst-launch-1.0 -e \
    v4l2src device="$VIDEO_NODE" num-buffers=1 io-mode=mmap ! \
    video/x-raw,format="$PIXEL_FORMAT",width="$WIDTH",height="$HEIGHT" ! \
    jpegenc ! \
    filesink location="$JPG_SAMPLE"
  assert_nonempty_file "$JPG_SAMPLE"
  ls -lh "$JPG_SAMPLE"
else
  echo "[WARN] gst-launch-1.0 not found, skip JPG export."
fi

section "Stability Test"
dmesg -T > "$DMESG_BEFORE"
before_lines="$(wc -l < "$DMESG_BEFORE")"

time v4l2-ctl -d "$VIDEO_NODE" \
  --set-fmt-video=width="$WIDTH",height="$HEIGHT",pixelformat="$PIXEL_FORMAT" \
  --stream-mmap=4 \
  --stream-skip="$STREAM_SKIP" \
  --stream-count="$STABLE_TEST_FRAMES" \
  --stream-to=/dev/null \
  --verbose

dmesg -T > "$DMESG_AFTER"
tail -n +"$((before_lines + 1))" "$DMESG_AFTER" > "$DMESG_DELTA" || true
grep -Ei 'ov13855|mipi|csi|rkisp|rkcif|timeout|error|fail' "$DMESG_DELTA" > "$DMESG_ERRORS" || true
cat "$DMESG_ERRORS"

unexpected_errors=0
if [[ -s "$DMESG_ERRORS" ]]; then
  if grep -Eiv "$IGNORE_PATTERN" "$DMESG_ERRORS" >/dev/null 2>&1; then
    unexpected_errors=1
  fi
fi

section "Fallback Raw Node"
echo "Configured raw fallback node: $RAW_VIDEO_NODE ($RAW_WIDTH x $RAW_HEIGHT $RAW_PIXEL_FORMAT)"

section "Result"
if [[ "$unexpected_errors" -eq 0 ]]; then
  echo "PASS: OV13855 bring-up smoke test completed."
  echo "Main node: $VIDEO_NODE"
  echo "Raw fallback node: $RAW_VIDEO_NODE"
  echo "Artifacts: $YUV_SAMPLE ${JPG_SAMPLE:-}"
  exit 0
fi

echo "FAIL: Found unexpected kernel errors during streaming."
echo "See: $DMESG_ERRORS"
exit 1
