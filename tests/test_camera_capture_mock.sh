#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
MOCK_BIN="$TMP_DIR/bin"
TEST_CONFIG="$TMP_DIR/ov13855_test.yaml"
BAD_CONFIG="$TMP_DIR/ov13855_bad.yaml"
LOG_DIR="$TMP_DIR/logs"
OUT_DIR="$TMP_DIR/samples"
VALIDATION_ROOT="$TMP_DIR/validation"
MANIFEST_PATH="$VALIDATION_ROOT/manifest.jsonl"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$MOCK_BIN" "$LOG_DIR" "$OUT_DIR" "$VALIDATION_ROOT"

cat > "$TEST_CONFIG" <<'EOF'
sensor_entity: "mock_ov13855 0-0036"
media_cif: "/dev/media1"
media_isp: "/dev/media3"
sample_dir: "samples/ov13855"
stable_test_frames: 300
main_profile: "preview"

mount_baseline:
  mount_id: "mock_mount_v1"
  status: "fixed"
  orientation: "landscape"
  height_mm: "100"
  tilt_deg: "15"
  work_distance_mm: "250"
  coverage_note: "mock"

validation_capture:
  root_dir: "samples/ov13855/validation"
  default_scene_tag: "empty_workbench"
  export_jpg: true
  manifest_path: "samples/ov13855/validation/manifest.jsonl"

profiles:
  preview:
    video_node: "/dev/video23"
    width: 1920
    height: 1080
    pixfmt: "NV12"
    fps: 30
    stream_skip: 10

presets:
  auto_baseline:
    enabled: true
    description: "auto"
    disabled_reason: ""
    controls:
  workbench_balanced:
    enabled: true
    description: "balanced"
    disabled_reason: ""
    controls:
      brightness: 10
  workbench_lowlight:
    enabled: false
    description: "lowlight"
    disabled_reason: "disabled for test"
    controls:
      brightness: 5
EOF

cat > "$BAD_CONFIG" <<'EOF'
sensor_entity: "mock_ov13855 0-0036"
media_cif: "/dev/media1"
media_isp: "/dev/media3"
sample_dir: "samples/ov13855"
stable_test_frames: 300
main_profile: "preview"

mount_baseline:
  mount_id: "mock_mount_v1"
  status: "fixed"
  orientation: "landscape"
  height_mm: "100"
  tilt_deg: "15"
  work_distance_mm: "250"
  coverage_note: "mock"

validation_capture:
  root_dir: "samples/ov13855/validation"
  default_scene_tag: "empty_workbench"
  export_jpg: true
  manifest_path: "samples/ov13855/validation/manifest.jsonl"

profiles:
  preview:
    video_node: "/dev/video23"
    width: 1920
    height: 1080
    pixfmt: "NV12"
    fps: 30
    stream_skip: 10

presets:
  auto_baseline:
    enabled: true
    description: "auto"
    disabled_reason: ""
    controls:
  bad_preset:
    enabled: true
    description: "bad"
    disabled_reason: ""
    controls:
      missing_control: 1
EOF

cat > "$MOCK_BIN/v4l2-ctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

for arg in "$@"; do
  case "$arg" in
    -L)
      cat <<'OUT'
brightness 0x00980900 (int)    : min=-64 max=64 step=1 default=0 value=0
contrast 0x00980901 (int)    : min=0 max=95 step=1 default=32 value=32
gain 0x00980913 (int)    : min=0 max=255 step=1 default=64 value=64
exposure_auto 0x009a0901 (menu)    : min=0 max=3 default=3 value=3
exposure_absolute 0x009a0902 (int)    : min=1 max=10000 step=1 default=100 value=100
white_balance_temperature_auto 0x0098090c (bool)    : default=1 value=1
white_balance_temperature 0x0098091a (int)    : min=2800 max=6500 step=10 default=4600 value=4600
sharpness 0x0098091b (int)    : min=0 max=10 step=1 default=5 value=5
OUT
      exit 0
      ;;
    --all)
      cat <<'OUT'
Driver name      : mock-camera
Card type        : mock-card
Brightness       : 0
Contrast         : 32
OUT
      exit 0
      ;;
    -D)
      cat <<'OUT'
Driver Info:
  Driver name      : mock-camera
  Card type        : mock-card
OUT
      exit 0
      ;;
    --list-formats-ext)
      cat <<'OUT'
ioctl: VIDIOC_ENUM_FMT
	Type: Video Capture Multiplanar
	[0]: 'NV12' (Y/CbCr 4:2:0)
		Size: Discrete 1920x1080
		Size: Discrete 3840x2160
OUT
      exit 0
      ;;
    --set-ctrl=*)
      printf '%s\n' "$arg" >> "${MOCK_SET_CTRL_LOG:?}"
      ;;
    --stream-to=*)
      output_path="${arg#--stream-to=}"
      mkdir -p "$(dirname "$output_path")"
      printf 'mock-frame\n' > "$output_path"
      ;;
  esac
done

exit 0
EOF
chmod +x "$MOCK_BIN/v4l2-ctl"

cat > "$MOCK_BIN/gst-launch-1.0" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

for arg in "$@"; do
  case "$arg" in
    location=*)
      output_path="${arg#location=}"
      mkdir -p "$(dirname "$output_path")"
      printf 'mock-jpg\n' > "$output_path"
      ;;
  esac
done

exit 0
EOF
chmod +x "$MOCK_BIN/gst-launch-1.0"

assert_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "[FAIL] Missing expected file: $path"
    exit 1
  fi
}

assert_grep() {
  local pattern="$1"
  local path="$2"
  if ! grep -F "$pattern" "$path" >/dev/null 2>&1; then
    echo "[FAIL] Expected pattern '$pattern' not found in $path"
    exit 1
  fi
}

export PATH="$MOCK_BIN:$PATH"
export MOCK_SET_CTRL_LOG="$TMP_DIR/set_ctrl.log"

CONFIG_FILE="$TEST_CONFIG" LOG_DIR="$LOG_DIR" OUT_DIR="$OUT_DIR" VALIDATION_ROOT="$VALIDATION_ROOT" MANIFEST_PATH="$MANIFEST_PATH" \
  bash "$REPO_ROOT/scripts/camera_capture.sh" info preview > "$TMP_DIR/info.out"
assert_grep "main_profile: preview" "$TMP_DIR/info.out"

CONFIG_FILE="$TEST_CONFIG" LOG_DIR="$LOG_DIR" OUT_DIR="$OUT_DIR" VALIDATION_ROOT="$VALIDATION_ROOT" MANIFEST_PATH="$MANIFEST_PATH" \
  bash "$REPO_ROOT/scripts/camera_capture.sh" controls preview > "$TMP_DIR/controls.out"
assert_grep "controls_log:" "$TMP_DIR/controls.out"

CONFIG_FILE="$TEST_CONFIG" LOG_DIR="$LOG_DIR" OUT_DIR="$OUT_DIR" VALIDATION_ROOT="$VALIDATION_ROOT" MANIFEST_PATH="$MANIFEST_PATH" \
  bash "$REPO_ROOT/scripts/camera_capture.sh" apply-preset preview workbench_balanced > "$TMP_DIR/apply.out"
assert_grep "brightness=10" "$MOCK_SET_CTRL_LOG"

CONFIG_FILE="$TEST_CONFIG" LOG_DIR="$LOG_DIR" OUT_DIR="$OUT_DIR" VALIDATION_ROOT="$VALIDATION_ROOT" MANIFEST_PATH="$MANIFEST_PATH" \
  bash "$REPO_ROOT/scripts/camera_capture.sh" baseline-shot preview empty_workbench auto_baseline > "$TMP_DIR/baseline_shot.out"

CONFIG_FILE="$TEST_CONFIG" LOG_DIR="$LOG_DIR" OUT_DIR="$OUT_DIR" VALIDATION_ROOT="$VALIDATION_ROOT" MANIFEST_PATH="$MANIFEST_PATH" \
  bash "$REPO_ROOT/scripts/camera_capture.sh" baseline-series preview bright_object workbench_balanced 3 > "$TMP_DIR/baseline_series.out"

assert_file "$MANIFEST_PATH"
line_count="$(wc -l < "$MANIFEST_PATH")"
if [[ "$line_count" -ne 4 ]]; then
  echo "[FAIL] Expected 4 manifest lines, got $line_count"
  exit 1
fi

first_sidecar="$(find "$VALIDATION_ROOT" -name '*.json' | sort | head -n 1)"
assert_file "$first_sidecar"
assert_grep '"capture_type":"validation"' "$first_sidecar"
assert_grep '"scene_tag":"' "$first_sidecar"
assert_grep '"requested_controls":' "$first_sidecar"
assert_grep '"controls_log_path":"' "$first_sidecar"

if CONFIG_FILE="$TEST_CONFIG" LOG_DIR="$LOG_DIR" OUT_DIR="$OUT_DIR" VALIDATION_ROOT="$VALIDATION_ROOT" MANIFEST_PATH="$MANIFEST_PATH" \
  bash "$REPO_ROOT/scripts/camera_capture.sh" apply-preset preview workbench_lowlight > "$TMP_DIR/disabled.out" 2>&1; then
  echo "[FAIL] Disabled preset should fail"
  exit 1
fi

if CONFIG_FILE="$BAD_CONFIG" LOG_DIR="$LOG_DIR" OUT_DIR="$OUT_DIR" VALIDATION_ROOT="$VALIDATION_ROOT" MANIFEST_PATH="$MANIFEST_PATH" \
  bash "$REPO_ROOT/scripts/camera_capture.sh" apply-preset preview bad_preset > "$TMP_DIR/bad.out" 2>&1; then
  echo "[FAIL] Unsupported control should fail"
  exit 1
fi

echo "PASS: camera_capture mock test completed."
