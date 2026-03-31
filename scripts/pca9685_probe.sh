#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/configs/pca9685.yaml}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/pca9685_probe_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

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

require_cmd i2cdetect
require_cmd i2cget

I2C_BUS="${I2C_BUS:-$(get_top_value i2c_bus)}"
ADDRESS="${ADDRESS:-$(get_top_value address)}"
FREQUENCY_HZ="${FREQUENCY_HZ:-$(get_top_value frequency_hz)}"
OE_MODE="${OE_MODE:-$(get_top_value oe_mode)}"
SERVO_POWER_SOURCE="${SERVO_POWER_SOURCE:-$(get_top_value servo_power_source)}"

section "Config"
echo "i2c_bus: ${I2C_BUS:-<unset>}"
echo "address: $ADDRESS"
echo "frequency_hz: $FREQUENCY_HZ"
echo "oe_mode: $OE_MODE"
echo "servo_power_source: $SERVO_POWER_SOURCE"

section "Detected Buses"
i2cdetect -l || true

if [[ -z "${I2C_BUS:-}" ]]; then
  echo
  echo "[ERROR] i2c_bus is empty. Set I2C_BUS=<bus> or update configs/pca9685.yaml after checking i2cdetect -l."
  exit 1
fi

section "Address Scan"
i2cdetect -y "$I2C_BUS"

addr_token="$(printf '%02x' $((ADDRESS)))"
if ! i2cdetect -y "$I2C_BUS" | grep -E "(^|[[:space:]])$addr_token($|[[:space:]])" >/dev/null 2>&1; then
  echo "[ERROR] PCA9685 address $ADDRESS not found on bus $I2C_BUS"
  exit 1
fi

section "Register Read"
echo "MODE1: $(i2cget -y "$I2C_BUS" "$ADDRESS" 0x00)"
echo "MODE2: $(i2cget -y "$I2C_BUS" "$ADDRESS" 0x01)"
echo "PRESCALE: $(i2cget -y "$I2C_BUS" "$ADDRESS" 0xFE)"

section "Result"
echo "PASS: PCA9685 probe finished."
echo "Log saved to: $LOG_FILE"
