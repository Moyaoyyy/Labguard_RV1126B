#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/bringup_ov13855_${TIMESTAMP}.log"
DMESG_PATTERN='ov13855|mipi|csi|rkisp|rkcif|rkispp|isp'

mkdir -p "$LOG_DIR"
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

require_cmd v4l2-ctl
require_cmd media-ctl

section "System"
uname -a
cat /etc/os-release

section "Tools"
command -v v4l2-ctl
command -v media-ctl

section "Video Devices"
v4l2-ctl --list-devices

section "Device Nodes"
ls -l /dev/video* /dev/media* 2>/dev/null || true

section "Kernel Messages"
dmesg -T | grep -Ei "$DMESG_PATTERN" || true

section "Media Topology"
for media in /dev/media*; do
  echo "--- $media ---"
  media-ctl -p -d "$media" || true
done

section "Video Capabilities"
for video in /dev/video*; do
  echo "--- $video ---"
  v4l2-ctl -d "$video" -D || true
  v4l2-ctl -d "$video" --list-formats-ext || true
done

section "Result"
echo "OV13855 Phase 1 bring-up check finished."
echo "Log saved to: $LOG_FILE"
