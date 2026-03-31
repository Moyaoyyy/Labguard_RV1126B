#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/configs/ov13855.yaml}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/samples/ov13855}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/camera_capture_${TIMESTAMP}.log"

mkdir -p "$OUT_DIR" "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

trim_yaml() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  printf '%s\n' "$value"
}

get_top_value() {
  local key="$1"
  awk -v key="$key" '
    function clean(v) {
      sub(/^[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      gsub(/^"|"$/, "", v)
      return v
    }
    $0 ~ "^" key ":" {
      line = $0
      sub("^" key ":[[:space:]]*", "", line)
      print clean(line)
      exit
    }
  ' "$CONFIG_FILE"
}

get_section_value() {
  local section="$1"
  local key="$2"
  awk -v section="$section" -v key="$key" '
    function clean(v) {
      sub(/^[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      gsub(/^"|"$/, "", v)
      return v
    }
    $0 ~ "^" section ":" {
      in_section = 1
      next
    }
    in_section && $0 ~ "^[^ ]" {
      in_section = 0
    }
    in_section && $0 ~ "^  " key ":" {
      line = $0
      sub("^  " key ":[[:space:]]*", "", line)
      print clean(line)
      exit
    }
  ' "$CONFIG_FILE"
}

get_profile_value() {
  local profile="$1"
  local key="$2"
  awk -v profile="$profile" -v key="$key" '
    function clean(v) {
      sub(/^[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      gsub(/^"|"$/, "", v)
      return v
    }
    $0 ~ "^profiles:" {
      in_profiles = 1
      next
    }
    in_profiles && $0 ~ "^[^ ]" {
      in_profiles = 0
    }
    in_profiles && $0 ~ "^  " profile ":" {
      in_profile = 1
      next
    }
    in_profile && $0 ~ "^  [A-Za-z0-9_]+:" {
      in_profile = 0
    }
    in_profile && $0 ~ "^    " key ":" {
      line = $0
      sub("^    " key ":[[:space:]]*", "", line)
      print clean(line)
      exit
    }
  ' "$CONFIG_FILE"
}

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

usage() {
  cat <<'EOF'
Usage:
  bash scripts/camera_capture.sh info [profile]
  bash scripts/camera_capture.sh preview [profile] [target] [frame_count]
  bash scripts/camera_capture.sh oneshot [profile] [target]
  bash scripts/camera_capture.sh stress [profile] [frames|seconds] [value]

Examples:
  bash scripts/camera_capture.sh info preview
  bash scripts/camera_capture.sh preview preview /dev/null 300
  bash scripts/camera_capture.sh oneshot preview
  bash scripts/camera_capture.sh stress preview frames 9000
  bash scripts/camera_capture.sh stress preview seconds 300
EOF
}

load_profile() {
  PROFILE="${1:-preview}"
  SENSOR_ENTITY="$(get_top_value sensor_entity)"
  MEDIA_CIF="$(get_top_value media_cif)"
  MEDIA_ISP="$(get_top_value media_isp)"
  SAMPLE_DIR_REL="$(get_top_value sample_dir)"
  AE_MODE="$(get_section_value camera_controls ae)"
  AWB_MODE="$(get_section_value camera_controls awb)"
  GAIN_MODE="$(get_section_value camera_controls gain)"
  EXPOSURE_MODE="$(get_section_value camera_controls exposure)"

  VIDEO_NODE="$(get_profile_value "$PROFILE" video_node)"
  WIDTH="$(get_profile_value "$PROFILE" width)"
  HEIGHT="$(get_profile_value "$PROFILE" height)"
  PIXFMT="$(get_profile_value "$PROFILE" pixfmt)"
  FPS="$(get_profile_value "$PROFILE" fps)"
  STREAM_SKIP="$(get_profile_value "$PROFILE" stream_skip)"

  if [[ -z "$VIDEO_NODE" || -z "$WIDTH" || -z "$HEIGHT" || -z "$PIXFMT" ]]; then
    echo "[ERROR] Unknown or incomplete profile: $PROFILE"
    exit 1
  fi

  if [[ -z "${FPS:-}" ]]; then
    FPS=30
  fi

  if [[ -z "${STREAM_SKIP:-}" ]]; then
    STREAM_SKIP=10
  fi
}

default_capture_path() {
  local ext
  ext="$(printf '%s' "$PIXFMT" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ext" == "nv12" || "$ext" == "uyvy" ]]; then
    ext="yuv"
  else
    ext="raw"
  fi
  printf '%s/%s_%sx%s_%s_%s.%s\n' \
    "$OUT_DIR" "$PROFILE" "$WIDTH" "$HEIGHT" "$(printf '%s' "$PIXFMT" | tr '[:upper:]' '[:lower:]')" "$TIMESTAMP" "$ext"
}

run_capture() {
  local target="$1"
  local frame_count="${2:-}"
  local -a cmd

  cmd=(
    v4l2-ctl
    -d "$VIDEO_NODE"
    --set-fmt-video=width="$WIDTH",height="$HEIGHT",pixelformat="$PIXFMT"
    --stream-mmap=4
    --stream-skip="$STREAM_SKIP"
  )

  if [[ -n "$frame_count" ]]; then
    cmd+=(--stream-count="$frame_count")
  fi

  if [[ -n "$target" ]]; then
    cmd+=(--stream-to="$target")
  fi

  cmd+=(--verbose)
  "${cmd[@]}"
}

command_info() {
  section "Profile"
  echo "profile: $PROFILE"
  echo "sensor_entity: $SENSOR_ENTITY"
  echo "media_cif: $MEDIA_CIF"
  echo "media_isp: $MEDIA_ISP"
  echo "video_node: $VIDEO_NODE"
  echo "width: $WIDTH"
  echo "height: $HEIGHT"
  echo "pixfmt: $PIXFMT"
  echo "fps: $FPS"
  echo "stream_skip: $STREAM_SKIP"
  echo "ae: $AE_MODE"
  echo "awb: $AWB_MODE"
  echo "gain: $GAIN_MODE"
  echo "exposure: $EXPOSURE_MODE"

  section "Video Node"
  v4l2-ctl -d "$VIDEO_NODE" -D || true
  v4l2-ctl -d "$VIDEO_NODE" --list-formats-ext || true
}

command_preview() {
  local target="${1:-/dev/null}"
  local frame_count="${2:-}"
  section "Preview"
  echo "target: $target"
  if [[ "$target" != "/dev/null" ]]; then
    mkdir -p "$(dirname "$target")"
  fi
  run_capture "$target" "$frame_count"
}

command_oneshot() {
  local target="${1:-$(default_capture_path)}"
  section "Oneshot"
  echo "output: $target"
  mkdir -p "$(dirname "$target")"
  run_capture "$target" 1
  ls -lh "$target"
}

command_stress() {
  local mode="${1:-frames}"
  local value="${2:-300}"
  local frame_count

  case "$mode" in
    frames)
      frame_count="$value"
      ;;
    seconds)
      frame_count=$((FPS * value))
      ;;
    *)
      echo "[ERROR] stress mode must be 'frames' or 'seconds'"
      exit 1
      ;;
  esac

  section "Stress"
  echo "mode: $mode"
  echo "value: $value"
  echo "frame_count: $frame_count"
  run_capture /dev/null "$frame_count"
}

require_cmd v4l2-ctl

SUBCOMMAND="${1:-}"
if [[ -z "$SUBCOMMAND" ]]; then
  usage
  exit 1
fi
shift || true

case "$SUBCOMMAND" in
  info)
    load_profile "${1:-preview}"
    command_info
    ;;
  preview)
    load_profile "${1:-preview}"
    shift || true
    command_preview "${1:-/dev/null}" "${2:-}"
    ;;
  oneshot)
    load_profile "${1:-preview}"
    shift || true
    command_oneshot "${1:-}"
    ;;
  stress)
    load_profile "${1:-preview}"
    shift || true
    command_stress "${1:-frames}" "${2:-300}"
    ;;
  *)
    usage
    exit 1
    ;;
esac

section "Result"
echo "Log saved to: $LOG_FILE"
