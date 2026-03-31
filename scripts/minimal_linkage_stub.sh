#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/minimal_linkage_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] Missing required command: python3"
  exit 1
fi

INPUT="${1:-}"
if [[ -n "$INPUT" ]]; then
  JSON_LINE="$(cat "$INPUT")"
else
  JSON_LINE="$(cat)"
fi

python3 - <<'PY' "$JSON_LINE"
import json
import sys

payload = json.loads(sys.argv[1])
required = ["frame_id", "width", "height", "cx", "cy", "score"]
missing = [key for key in required if key not in payload]
if missing:
    raise SystemExit(f"[ERROR] Missing fields: {', '.join(missing)}")

result = {
    "event": "fixed_grab_stub",
    "frame_id": payload["frame_id"],
    "cx": payload["cx"],
    "cy": payload["cy"],
    "action": "trigger_fixed_grab_stub",
}
print(json.dumps(result, ensure_ascii=True))
PY

echo "Log saved to: $LOG_FILE"
