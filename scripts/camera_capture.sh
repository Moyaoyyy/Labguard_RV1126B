#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/configs/ov13855.yaml}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/camera_capture_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

resolve_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$path"
  fi
}

sanitize_token() {
  local token="$1"
  token="$(printf '%s' "$token" | sed 's/[^A-Za-z0-9_.-]/_/g')"
  if [[ -z "$token" ]]; then
    token="unknown"
  fi
  printf '%s\n' "$token"
}

json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

is_true() {
  case "${1:-}" in
    true|True|TRUE|yes|Yes|YES|1|on|On|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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

get_named_item_value() {
  local section_name="$1"
  local item_name="$2"
  local key="$3"
  awk -v section_name="$section_name" -v item_name="$item_name" -v key="$key" '
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
    in_section && $0 ~ "^  " item_name ":" {
      in_item = 1
      next
    }
    in_item && $0 ~ "^  [A-Za-z0-9_]+:" {
      in_item = 0
    }
    in_item && $0 ~ "^    " key ":" {
      line = $0
      sub("^    " key ":[[:space:]]*", "", line)
      print clean(line)
      exit
    }
  ' "$CONFIG_FILE"
}

list_named_items() {
  local section_name="$1"
  awk -v section_name="$section_name" '
    $0 ~ "^" section_name ":" {
      in_section = 1
      next
    }
    in_section && $0 ~ "^[^ ]" {
      in_section = 0
    }
    in_section && $0 ~ "^  [A-Za-z0-9_]+:" {
      item = $1
      sub(":", "", item)
      print item
    }
  ' "$CONFIG_FILE"
}

get_named_subsection_pairs() {
  local section_name="$1"
  local item_name="$2"
  local subsection_name="$3"
  awk -v section_name="$section_name" -v item_name="$item_name" -v subsection_name="$subsection_name" '
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
    in_section && $0 ~ "^  " item_name ":" {
      in_item = 1
      next
    }
    in_item && $0 ~ "^  [A-Za-z0-9_]+:" {
      in_item = 0
      in_subsection = 0
    }
    in_item && $0 ~ "^    " subsection_name ":" {
      in_subsection = 1
      next
    }
    in_subsection && $0 ~ "^    [A-Za-z0-9_]+:" {
      in_subsection = 0
    }
    in_subsection && $0 ~ "^      [A-Za-z0-9_]+:" {
      line = $0
      sub("^      ", "", line)
      key = line
      sub(":.*$", "", key)
      sub("^[^:]+:[[:space:]]*", "", line)
      print key "=" clean(line)
    }
  ' "$CONFIG_FILE"
}

get_profile_value() {
  get_named_item_value "profiles" "$1" "$2"
}

get_preset_value() {
  get_named_item_value "presets" "$1" "$2"
}

get_preset_controls() {
  get_named_subsection_pairs "presets" "$1" "controls"
}

load_globals() {
  SENSOR_ENTITY="$(get_top_value sensor_entity)"
  MEDIA_CIF="$(get_top_value media_cif)"
  MEDIA_ISP="$(get_top_value media_isp)"
  SAMPLE_DIR_REL="$(get_top_value sample_dir)"
  STABLE_TEST_FRAMES="$(get_top_value stable_test_frames)"
  MAIN_PROFILE="$(get_top_value main_profile)"

  MOUNT_ID="$(get_section_value mount_baseline mount_id)"
  MOUNT_STATUS="$(get_section_value mount_baseline status)"
  MOUNT_ORIENTATION="$(get_section_value mount_baseline orientation)"
  MOUNT_HEIGHT_MM="$(get_section_value mount_baseline height_mm)"
  MOUNT_TILT_DEG="$(get_section_value mount_baseline tilt_deg)"
  MOUNT_WORK_DISTANCE_MM="$(get_section_value mount_baseline work_distance_mm)"
  MOUNT_COVERAGE_NOTE="$(get_section_value mount_baseline coverage_note)"

  VALIDATION_ROOT_REL="$(get_section_value validation_capture root_dir)"
  DEFAULT_SCENE_TAG="$(get_section_value validation_capture default_scene_tag)"
  EXPORT_JPG="$(get_section_value validation_capture export_jpg)"
  MANIFEST_REL="$(get_section_value validation_capture manifest_path)"

  if [[ -z "${MAIN_PROFILE:-}" ]]; then
    MAIN_PROFILE="preview"
  fi
  if [[ -z "${STABLE_TEST_FRAMES:-}" ]]; then
    STABLE_TEST_FRAMES="300"
  fi

  OUT_DIR="${OUT_DIR:-$(resolve_path "$SAMPLE_DIR_REL")}"
  VALIDATION_ROOT="${VALIDATION_ROOT:-$(resolve_path "$VALIDATION_ROOT_REL")}"
  MANIFEST_PATH="${MANIFEST_PATH:-$(resolve_path "$MANIFEST_REL")}"

  mkdir -p "$OUT_DIR" "$VALIDATION_ROOT" "$(dirname "$MANIFEST_PATH")"
}

load_profile() {
  load_globals

  PROFILE="${1:-$MAIN_PROFILE}"
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

snapshot_controls() {
  local tag="$1"
  local safe_tag
  safe_tag="$(sanitize_token "$tag")"
  CONTROL_SNAPSHOT_PATH="$LOG_DIR/controls_${PROFILE}_${safe_tag}_${TIMESTAMP}.log"

  {
    echo "profile: $PROFILE"
    echo "video_node: $VIDEO_NODE"
    echo "preset: ${ACTIVE_PRESET:-<none>}"
    echo "scene: ${ACTIVE_SCENE_TAG:-<none>}"
    echo "timestamp: $TIMESTAMP"
    echo
    echo "----- v4l2-ctl -L -----"
    v4l2-ctl -d "$VIDEO_NODE" -L
    echo
    echo "----- v4l2-ctl --all -----"
    v4l2-ctl -d "$VIDEO_NODE" --all
  } | tee "$CONTROL_SNAPSHOT_PATH"
}

build_requested_controls_json() {
  local preset="$1"
  local first=1
  local json="{"
  local pair key value

  while IFS= read -r pair; do
    [[ -z "$pair" ]] && continue
    key="${pair%%=*}"
    value="${pair#*=}"
    if [[ "$first" -eq 0 ]]; then
      json+=","
    fi
    json+="\"$(json_escape "$key")\":\"$(json_escape "$value")\""
    first=0
  done < <(get_preset_controls "$preset")

  json+="}"
  printf '%s\n' "$json"
}

build_set_ctrl_string() {
  local preset="$1"
  local first=1
  local set_ctrl=""
  local pair key value

  while IFS= read -r pair; do
    [[ -z "$pair" ]] && continue
    key="${pair%%=*}"
    value="${pair#*=}"
    if [[ "$first" -eq 0 ]]; then
      set_ctrl+=","
    fi
    set_ctrl+="${key}=${value}"
    first=0
  done < <(get_preset_controls "$preset")

  printf '%s\n' "$set_ctrl"
}

validate_preset() {
  local preset="$1"
  local enabled disabled_reason
  local control_dump pair control_name
  local -a missing_controls=()

  enabled="$(get_preset_value "$preset" enabled)"
  if [[ -z "$enabled" ]]; then
    echo "[ERROR] Unknown preset: $preset"
    exit 1
  fi

  if ! is_true "$enabled"; then
    disabled_reason="$(get_preset_value "$preset" disabled_reason)"
    if [[ -n "$disabled_reason" ]]; then
      echo "[ERROR] Preset '$preset' is disabled: $disabled_reason"
    else
      echo "[ERROR] Preset '$preset' is disabled."
    fi
    exit 1
  fi

  control_dump="$(mktemp)"
  v4l2-ctl -d "$VIDEO_NODE" -L > "$control_dump"

  while IFS= read -r pair; do
    [[ -z "$pair" ]] && continue
    control_name="${pair%%=*}"
    if ! awk -v ctrl="$control_name" '$1 == ctrl {found = 1} END {exit !found}' "$control_dump"; then
      missing_controls+=("$control_name")
    fi
  done < <(get_preset_controls "$preset")

  rm -f "$control_dump"

  if [[ "${#missing_controls[@]}" -gt 0 ]]; then
    echo "[ERROR] Preset '$preset' references unsupported controls:"
    printf '  - %s\n' "${missing_controls[@]}"
    exit 1
  fi
}

apply_preset() {
  local preset="$1"
  local set_ctrl_string

  validate_preset "$preset"
  ACTIVE_PRESET="$preset"
  set_ctrl_string="$(build_set_ctrl_string "$preset")"

  section "Apply Preset"
  echo "profile: $PROFILE"
  echo "preset: $preset"

  if [[ -z "$set_ctrl_string" ]]; then
    echo "requested_controls: <none>"
    echo "action: no-op (preset has no explicit controls yet)"
  else
    echo "requested_controls: $set_ctrl_string"
    v4l2-ctl -d "$VIDEO_NODE" --set-ctrl="$set_ctrl_string"
  fi

  snapshot_controls "preset_${preset}"
  APPLIED_CONTROLS_LOG="$CONTROL_SNAPSHOT_PATH"
}

write_sidecar_json() {
  local sidecar_path="$1"
  local scene_tag="$2"
  local preset="$3"
  local output_path="$4"
  local preview_path="$5"
  local controls_log_path="$6"
  local requested_controls_json
  local json_line

  requested_controls_json="$(build_requested_controls_json "$preset")"
  json_line=$(
    printf '{"capture_type":"validation","scene_tag":"%s","profile":"%s","preset":"%s","video_node":"%s","width":"%s","height":"%s","pixfmt":"%s","fps":"%s","timestamp":"%s","mount_id":"%s","output_path":"%s","preview_path":"%s","requested_controls":%s,"controls_log_path":"%s"}' \
      "$(json_escape "$scene_tag")" \
      "$(json_escape "$PROFILE")" \
      "$(json_escape "$preset")" \
      "$(json_escape "$VIDEO_NODE")" \
      "$(json_escape "$WIDTH")" \
      "$(json_escape "$HEIGHT")" \
      "$(json_escape "$PIXFMT")" \
      "$(json_escape "$FPS")" \
      "$(json_escape "$TIMESTAMP")" \
      "$(json_escape "$MOUNT_ID")" \
      "$(json_escape "$output_path")" \
      "$(json_escape "$preview_path")" \
      "$requested_controls_json" \
      "$(json_escape "$controls_log_path")"
  )

  printf '%s\n' "$json_line" > "$sidecar_path"
  printf '%s\n' "$json_line" >> "$MANIFEST_PATH"
}

export_preview_jpg() {
  local preview_path="$1"

  GENERATED_PREVIEW_PATH=""
  PREVIEW_SKIP_REASON=""

  if ! is_true "$EXPORT_JPG"; then
    PREVIEW_SKIP_REASON="disabled_by_config"
    return 0
  fi

  if ! command -v gst-launch-1.0 >/dev/null 2>&1; then
    PREVIEW_SKIP_REASON="gst-launch-1.0_not_found"
    return 0
  fi

  if ! gst-launch-1.0 -e \
    v4l2src device="$VIDEO_NODE" num-buffers=1 io-mode=mmap ! \
    video/x-raw,format="$PIXFMT",width="$WIDTH",height="$HEIGHT" ! \
    jpegenc ! \
    filesink location="$preview_path"; then
    PREVIEW_SKIP_REASON="gst_preview_export_failed"
    return 0
  fi

  GENERATED_PREVIEW_PATH="$preview_path"
}

capture_validation_shot() {
  local scene_tag="$1"
  local preset="$2"
  local suffix="${3:-}"
  local safe_scene safe_preset base_name output_path sidecar_path preview_path
  local ext preview_record

  ACTIVE_SCENE_TAG="$scene_tag"
  apply_preset "$preset"

  safe_scene="$(sanitize_token "$scene_tag")"
  safe_preset="$(sanitize_token "$preset")"
  ext="$(printf '%s' "$PIXFMT" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ext" == "nv12" || "$ext" == "uyvy" ]]; then
    ext="yuv"
  else
    ext="raw"
  fi

  base_name="${safe_scene}_${PROFILE}_${safe_preset}_${TIMESTAMP}"
  if [[ -n "$suffix" ]]; then
    base_name="${base_name}_$(sanitize_token "$suffix")"
  fi

  mkdir -p "$VALIDATION_ROOT/$safe_scene"
  output_path="$VALIDATION_ROOT/$safe_scene/${base_name}.${ext}"
  sidecar_path="$VALIDATION_ROOT/$safe_scene/${base_name}.json"
  preview_path="$VALIDATION_ROOT/$safe_scene/${base_name}.jpg"

  section "Baseline Shot"
  echo "scene_tag: $scene_tag"
  echo "profile: $PROFILE"
  echo "preset: $preset"
  echo "output: $output_path"
  run_capture "$output_path" 1
  ls -lh "$output_path"

  export_preview_jpg "$preview_path"
  if [[ -n "$GENERATED_PREVIEW_PATH" ]]; then
    preview_record="$GENERATED_PREVIEW_PATH"
    ls -lh "$GENERATED_PREVIEW_PATH"
  else
    preview_record=""
    echo "[WARN] Preview JPG skipped: ${PREVIEW_SKIP_REASON:-unknown_reason}"
  fi

  write_sidecar_json "$sidecar_path" "$scene_tag" "$preset" "$output_path" "$preview_record" "$APPLIED_CONTROLS_LOG"
  echo "sidecar: $sidecar_path"
  echo "manifest: $MANIFEST_PATH"
}

command_info() {
  local preset_name enabled description disabled_reason

  section "Phase 2A"
  echo "main_profile: $MAIN_PROFILE"
  echo "stable_test_frames: $STABLE_TEST_FRAMES"
  echo "log_file: $LOG_FILE"

  section "Mount Baseline"
  echo "mount_id: $MOUNT_ID"
  echo "status: $MOUNT_STATUS"
  echo "orientation: $MOUNT_ORIENTATION"
  echo "height_mm: $MOUNT_HEIGHT_MM"
  echo "tilt_deg: $MOUNT_TILT_DEG"
  echo "work_distance_mm: $MOUNT_WORK_DISTANCE_MM"
  echo "coverage_note: $MOUNT_COVERAGE_NOTE"

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

  section "Validation Capture"
  echo "sample_dir: $OUT_DIR"
  echo "validation_root: $VALIDATION_ROOT"
  echo "default_scene_tag: $DEFAULT_SCENE_TAG"
  echo "export_jpg: $EXPORT_JPG"
  echo "manifest_path: $MANIFEST_PATH"

  section "Presets"
  while IFS= read -r preset_name; do
    [[ -z "$preset_name" ]] && continue
    enabled="$(get_preset_value "$preset_name" enabled)"
    description="$(get_preset_value "$preset_name" description)"
    disabled_reason="$(get_preset_value "$preset_name" disabled_reason)"
    echo "preset: $preset_name"
    echo "  enabled: $enabled"
    echo "  description: $description"
    if [[ -n "$disabled_reason" ]]; then
      echo "  disabled_reason: $disabled_reason"
    fi
  done < <(list_named_items presets)

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
  local value="${2:-$STABLE_TEST_FRAMES}"
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

command_controls() {
  section "Controls"
  echo "profile: $PROFILE"
  snapshot_controls "survey"
  echo "controls_log: $CONTROL_SNAPSHOT_PATH"
}

command_apply_preset() {
  local preset="${1:-auto_baseline}"
  apply_preset "$preset"
  echo "controls_log: $APPLIED_CONTROLS_LOG"
}

command_baseline_shot() {
  local scene_tag="${1:-$DEFAULT_SCENE_TAG}"
  local preset="${2:-auto_baseline}"
  capture_validation_shot "$scene_tag" "$preset"
}

command_baseline_series() {
  local scene_tag="${1:-$DEFAULT_SCENE_TAG}"
  local preset="${2:-auto_baseline}"
  local count="${3:-3}"
  local index

  if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -lt 1 ]]; then
    echo "[ERROR] baseline-series count must be a positive integer"
    exit 1
  fi

  section "Baseline Series"
  echo "scene_tag: $scene_tag"
  echo "preset: $preset"
  echo "count: $count"

  for index in $(seq 1 "$count"); do
    capture_validation_shot "$scene_tag" "$preset" "$index"
  done
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/camera_capture.sh info [profile]
  bash scripts/camera_capture.sh preview [profile] [target] [frame_count]
  bash scripts/camera_capture.sh oneshot [profile] [target]
  bash scripts/camera_capture.sh stress [profile] [frames|seconds] [value]
  bash scripts/camera_capture.sh controls [profile]
  bash scripts/camera_capture.sh apply-preset [profile] [preset]
  bash scripts/camera_capture.sh baseline-shot [profile] [scene_tag] [preset]
  bash scripts/camera_capture.sh baseline-series [profile] [scene_tag] [preset] [count]

Examples:
  bash scripts/camera_capture.sh info preview
  bash scripts/camera_capture.sh controls preview
  bash scripts/camera_capture.sh apply-preset preview workbench_balanced
  bash scripts/camera_capture.sh baseline-shot preview empty_workbench auto_baseline
  bash scripts/camera_capture.sh baseline-series preview bright_object workbench_balanced 3
  bash scripts/camera_capture.sh stress preview seconds 300
EOF
}

require_cmd v4l2-ctl
load_globals

SUBCOMMAND="${1:-}"
if [[ -z "$SUBCOMMAND" ]]; then
  usage
  exit 1
fi
shift || true

case "$SUBCOMMAND" in
  info)
    load_profile "${1:-$MAIN_PROFILE}"
    command_info
    ;;
  preview)
    load_profile "${1:-$MAIN_PROFILE}"
    shift || true
    command_preview "${1:-/dev/null}" "${2:-}"
    ;;
  oneshot)
    load_profile "${1:-$MAIN_PROFILE}"
    shift || true
    command_oneshot "${1:-}"
    ;;
  stress)
    load_profile "${1:-$MAIN_PROFILE}"
    shift || true
    command_stress "${1:-frames}" "${2:-$STABLE_TEST_FRAMES}"
    ;;
  controls)
    load_profile "${1:-$MAIN_PROFILE}"
    command_controls
    ;;
  apply-preset)
    load_profile "${1:-$MAIN_PROFILE}"
    shift || true
    command_apply_preset "${1:-auto_baseline}"
    ;;
  baseline-shot)
    load_profile "${1:-$MAIN_PROFILE}"
    shift || true
    command_baseline_shot "${1:-$DEFAULT_SCENE_TAG}" "${2:-auto_baseline}"
    ;;
  baseline-series)
    load_profile "${1:-$MAIN_PROFILE}"
    shift || true
    command_baseline_series "${1:-$DEFAULT_SCENE_TAG}" "${2:-auto_baseline}" "${3:-3}"
    ;;
  *)
    usage
    exit 1
    ;;
esac

section "Result"
echo "Log saved to: $LOG_FILE"
