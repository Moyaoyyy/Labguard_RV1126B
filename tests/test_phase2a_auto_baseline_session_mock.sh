#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d)"
TMP_REPO="$TMP_DIR/repo"
MOCK_BIN="$TMP_DIR/bin"
INVOCATION_LOG="$TMP_DIR/invocations.log"
CONFIG_FILE="$TMP_REPO/configs/ov13855.yaml"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_REPO/scripts" "$TMP_REPO/configs" "$TMP_REPO/samples/ov13855/validation" "$TMP_REPO/logs" "$MOCK_BIN"
cp "$REPO_ROOT/scripts/run_phase2a_auto_baseline_session.sh" "$TMP_REPO/scripts/"
chmod +x "$TMP_REPO/scripts/run_phase2a_auto_baseline_session.sh"

cat > "$CONFIG_FILE" <<'EOF'
sensor_entity: "mock_ov13855 0-0036"
media_cif: "/dev/media1"
media_isp: "/dev/media3"
sample_dir: "samples/ov13855"
stable_test_frames: 300
main_profile: "preview"

mount_baseline:
  mount_id: "workbench_main_v1"
  status: "fixed"
  orientation: "landscape"
  height_mm: "100"
  tilt_deg: "15"
  work_distance_mm: "250"
  coverage_note: "Center ROI fully covered. Edge bins visible on all four sides."

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
EOF

cat > "$TMP_REPO/samples/ov13855/validation/README.md" <<'EOF'
validation readme
EOF

cat > "$TMP_REPO/scripts/camera_capture.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE_DIR="$REPO_ROOT/samples/ov13855"
VALIDATION_ROOT="$SAMPLE_DIR/validation"
MANIFEST_PATH="$VALIDATION_ROOT/manifest.jsonl"

printf '%s\n' "$*" >> "${INVOCATION_LOG:?}"

case "${1:-}" in
  info)
    echo "phase2a_mount_gate: ready"
    ;;
  oneshot)
    mkdir -p "$SAMPLE_DIR"
    printf 'oneshot\n' > "$SAMPLE_DIR/preview_mock_capture.yuv"
    ;;
  stress)
    echo "stress ok: ${2:-} ${3:-} ${4:-}"
    ;;
  controls)
    mkdir -p "$REPO_ROOT/logs"
    printf 'mock controls\n' > "$REPO_ROOT/logs/controls_preview_survey_mock.log"
    echo "controls_log: $REPO_ROOT/logs/controls_preview_survey_mock.log"
    ;;
  baseline-series)
    profile="${2:?}"
    scene="${3:?}"
    preset="${4:?}"
    count="${5:?}"
    mkdir -p "$VALIDATION_ROOT/$scene"
    for index in $(seq 1 "$count"); do
      raw_path="$VALIDATION_ROOT/$scene/${scene}_${profile}_${preset}_${index}.yuv"
      sidecar_path="$VALIDATION_ROOT/$scene/${scene}_${profile}_${preset}_${index}.json"
      printf 'frame\n' > "$raw_path"
      printf '{"capture_type":"validation","scene_tag":"%s","profile":"%s","preset":"%s"}\n' "$scene" "$profile" "$preset" > "$sidecar_path"
      printf '{"capture_type":"validation","scene_tag":"%s","profile":"%s","preset":"%s"}\n' "$scene" "$profile" "$preset" >> "$MANIFEST_PATH"
    done
    ;;
  *)
    echo "unexpected subcommand: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$TMP_REPO/scripts/camera_capture.sh"

cat > "$MOCK_BIN/uname" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-m" ]]; then
  printf 'aarch64\n'
else
  printf 'Linux mock-board 6.1.141 aarch64\n'
fi
EOF
chmod +x "$MOCK_BIN/uname"

cat > "$MOCK_BIN/v4l2-ctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/v4l2-ctl"

cat > "$MOCK_BIN/media-ctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/media-ctl"

cat > "$MOCK_BIN/gst-launch-1.0" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/gst-launch-1.0"

assert_grep() {
  local pattern="$1"
  local path="$2"
  if ! grep -F "$pattern" "$path" >/dev/null 2>&1; then
    echo "[FAIL] Expected pattern '$pattern' not found in $path"
    exit 1
  fi
}

assert_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "[FAIL] Missing expected file: $path"
    exit 1
  fi
}

export PATH="$MOCK_BIN:/usr/bin:/bin"
export INVOCATION_LOG

CONFIG_FILE="$CONFIG_FILE" LOG_DIR="$TMP_REPO/logs" \
  bash "$TMP_REPO/scripts/run_phase2a_auto_baseline_session.sh" > "$TMP_DIR/session.out"

assert_grep "PASS: Phase 2A auto_baseline session completed." "$TMP_DIR/session.out"
assert_grep "manifest_lines: 18" "$TMP_DIR/session.out"
assert_grep "sidecar_count: 18" "$TMP_DIR/session.out"
assert_grep "raw_capture_count: 18" "$TMP_DIR/session.out"

assert_file "$TMP_REPO/samples/ov13855/preview_mock_capture.yuv"
assert_file "$TMP_REPO/samples/ov13855/validation/manifest.jsonl"

expected_invocations="$(cat <<'EOF'
info preview
oneshot preview
stress preview frames 300
controls preview
baseline-series preview empty_workbench auto_baseline 3
baseline-series preview center_marker auto_baseline 3
baseline-series preview bright_object auto_baseline 3
baseline-series preview dark_object auto_baseline 3
baseline-series preview reflective_object auto_baseline 3
baseline-series preview edge_coverage auto_baseline 3
stress preview seconds 300
EOF
)"

if [[ "$(cat "$INVOCATION_LOG")" != "$expected_invocations" ]]; then
  echo "[FAIL] Unexpected camera_capture invocation order"
  echo "Expected:"
  printf '%s\n' "$expected_invocations"
  echo "Actual:"
  cat "$INVOCATION_LOG"
  exit 1
fi

for scene in empty_workbench center_marker bright_object dark_object reflective_object edge_coverage; do
  if [[ ! -d "$TMP_REPO/samples/ov13855/validation/$scene" ]]; then
    echo "[FAIL] Missing scene directory: $scene"
    exit 1
  fi
done

echo "PASS: phase2a auto baseline session mock test completed."
