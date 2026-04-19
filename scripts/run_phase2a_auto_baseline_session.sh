#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/configs/ov13855.yaml}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/phase2a_auto_baseline_${TIMESTAMP}.log"

PROFILE="preview"
PRESET="auto_baseline"
FRAME_STRESS=300
SECOND_STRESS=300
SERIES_COUNT=3
SCENES=(
  empty_workbench
  center_marker
  bright_object
  dark_object
  reflective_object
  edge_coverage
)

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

resolve_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$path"
  fi
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
  local section_name="$1"
  local key="$2"
  awk -v section_name="$section_name" -v key="$key" '
    function clean(v) {
      sub(/^[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      gsub(/^"|"$/, "", v)
      return v
    }
    $0 ~ "^" section_name ":" {
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

load_paths() {
  SAMPLE_DIR_REL="$(get_top_value sample_dir)"
  VALIDATION_ROOT_REL="$(get_section_value validation_capture root_dir)"
  MANIFEST_REL="$(get_section_value validation_capture manifest_path)"

  SAMPLE_DIR="$(resolve_path "$SAMPLE_DIR_REL")"
  VALIDATION_ROOT="$(resolve_path "$VALIDATION_ROOT_REL")"
  MANIFEST_PATH="$(resolve_path "$MANIFEST_REL")"
}

assert_target_board() {
  local arch

  arch="$(uname -m)"
  case "$arch" in
    x86_64|i386|i486|i586|i686)
      echo "[ERROR] This session runner must be executed on the RV1126B board, not on the Fedora host."
      echo "Detected architecture: $arch"
      exit 1
      ;;
  esac
}

assert_clean_validation_root() {
  local dirty_entry

  mkdir -p "$VALIDATION_ROOT"
  dirty_entry="$(find "$VALIDATION_ROOT" -mindepth 1 ! -name README.md -print -quit)"
  if [[ -n "$dirty_entry" ]]; then
    echo "[ERROR] Validation root is not clean: $dirty_entry"
    echo "Archive or remove old Phase 2A validation artifacts before starting a new auto_baseline session."
    exit 1
  fi
}

count_oneshot_samples() {
  find "$SAMPLE_DIR" -maxdepth 1 -type f \( -name "${PROFILE}_*.yuv" -o -name "${PROFILE}_*.raw" \) | wc -l
}

run_capture() {
  section "$1"
  shift
  echo "command: bash scripts/camera_capture.sh $*"
  bash "$REPO_ROOT/scripts/camera_capture.sh" "$@"
}

verify_manifest() {
  local manifest_lines
  local sidecar_count
  local raw_count
  local bad_sidecar=0
  local scene
  local json_path

  section "Evidence Check"

  if [[ ! -f "$MANIFEST_PATH" ]]; then
    echo "[ERROR] Missing manifest: $MANIFEST_PATH"
    exit 1
  fi

  manifest_lines="$(wc -l < "$MANIFEST_PATH")"
  sidecar_count="$(find "$VALIDATION_ROOT" -name '*.json' | wc -l)"
  raw_count="$(find "$VALIDATION_ROOT" -type f \( -name '*.yuv' -o -name '*.raw' \) | wc -l)"

  echo "manifest_lines: $manifest_lines"
  echo "sidecar_count: $sidecar_count"
  echo "raw_capture_count: $raw_count"

  if [[ "$manifest_lines" -ne 18 ]]; then
    echo "[ERROR] Expected 18 manifest lines, got $manifest_lines"
    exit 1
  fi
  if [[ "$sidecar_count" -ne 18 ]]; then
    echo "[ERROR] Expected 18 sidecar JSON files, got $sidecar_count"
    exit 1
  fi
  if [[ "$raw_count" -ne 18 ]]; then
    echo "[ERROR] Expected 18 raw validation captures, got $raw_count"
    exit 1
  fi

  while IFS= read -r json_path; do
    if ! grep -F '"preset":"auto_baseline"' "$json_path" >/dev/null 2>&1; then
      echo "[ERROR] Sidecar does not record preset auto_baseline: $json_path"
      bad_sidecar=1
    fi
  done < <(find "$VALIDATION_ROOT" -name '*.json' | sort)

  if [[ "$bad_sidecar" -ne 0 ]]; then
    exit 1
  fi

  for scene in "${SCENES[@]}"; do
    if [[ ! -d "$VALIDATION_ROOT/$scene" ]]; then
      echo "[ERROR] Missing scene directory: $VALIDATION_ROOT/$scene"
      exit 1
    fi
  done
}

main() {
  local oneshot_before
  local oneshot_after
  local scene

  require_cmd bash
  require_cmd find
  require_cmd grep
  require_cmd media-ctl
  require_cmd gst-launch-1.0
  require_cmd sort
  require_cmd uname
  require_cmd v4l2-ctl
  require_cmd wc

  load_paths

  section "Preflight"
  echo "config_file: $CONFIG_FILE"
  echo "sample_dir: $SAMPLE_DIR"
  echo "validation_root: $VALIDATION_ROOT"
  echo "manifest_path: $MANIFEST_PATH"
  echo "session_log: $LOG_FILE"
  echo "board_arch: $(uname -m)"
  echo "kernel: $(uname -a)"

  assert_target_board
  assert_clean_validation_root

  mkdir -p "$SAMPLE_DIR"
  oneshot_before="$(count_oneshot_samples)"

  run_capture "Info" info "$PROFILE"
  run_capture "Oneshot" oneshot "$PROFILE"

  oneshot_after="$(count_oneshot_samples)"
  echo "oneshot_before: $oneshot_before"
  echo "oneshot_after: $oneshot_after"
  if [[ "$oneshot_after" -le "$oneshot_before" ]]; then
    echo "[ERROR] Expected oneshot to create a new raw sample in $SAMPLE_DIR"
    exit 1
  fi

  run_capture "Stress 300 Frames" stress "$PROFILE" frames "$FRAME_STRESS"
  run_capture "Controls" controls "$PROFILE"

  for scene in "${SCENES[@]}"; do
    run_capture "Baseline Series ${scene}" baseline-series "$PROFILE" "$scene" "$PRESET" "$SERIES_COUNT"
  done

  run_capture "Stress 300 Seconds" stress "$PROFILE" seconds "$SECOND_STRESS"
  verify_manifest

  section "Result"
  echo "PASS: Phase 2A auto_baseline session completed."
  echo "log: $LOG_FILE"
}

main "$@"
