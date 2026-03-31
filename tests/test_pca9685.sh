#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/configs/pca9685.yaml}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/test_pca9685_${TIMESTAMP}.log"

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

hex_byte() {
  printf '0x%02x' "$1"
}

write_reg() {
  local reg="$1"
  local value="$2"
  i2cset -y "$I2C_BUS" "$ADDRESS" "$reg" "$value" >/dev/null
}

read_reg() {
  local reg="$1"
  i2cget -y "$I2C_BUS" "$ADDRESS" "$reg"
}

set_pwm_frequency() {
  local prescale
  prescale=$((25000000 / (4096 * FREQUENCY_HZ) - 1))

  section "PWM Frequency"
  echo "frequency_hz: $FREQUENCY_HZ"
  echo "prescale: $prescale"

  write_reg 0x00 0x10
  write_reg 0xFE "$(hex_byte "$prescale")"
  write_reg 0x00 0x20
  sleep 1
  write_reg 0x00 0xA0
  write_reg 0x01 0x04

  echo "MODE1: $(read_reg 0x00)"
  echo "MODE2: $(read_reg 0x01)"
  echo "PRESCALE: $(read_reg 0xFE)"
}

set_channel_pulse_us() {
  local channel="$1"
  local pulse_us="$2"
  local base
  local ticks
  local off_l
  local off_h

  base=$((0x06 + 4 * channel))
  ticks=$((pulse_us * FREQUENCY_HZ * 4096 / 1000000))
  off_l=$((ticks & 0xFF))
  off_h=$(((ticks >> 8) & 0x0F))

  echo "channel=$channel pulse_us=$pulse_us ticks=$ticks"
  write_reg "$(hex_byte "$base")" 0x00
  write_reg "$(hex_byte $((base + 1)))" 0x00
  write_reg "$(hex_byte $((base + 2)))" "$(hex_byte "$off_l")"
  write_reg "$(hex_byte $((base + 3)))" "$(hex_byte "$off_h")"
}

require_cmd i2cdetect
require_cmd i2cget
require_cmd i2cset

I2C_BUS="${I2C_BUS:-$(get_top_value i2c_bus)}"
ADDRESS="${ADDRESS:-$(get_top_value address)}"
FREQUENCY_HZ="${FREQUENCY_HZ:-$(get_top_value frequency_hz)}"
TEST_CHANNEL="${TEST_CHANNEL:-$(get_top_value test_channel)}"
CENTER_US="${CENTER_US:-$(get_section_value pulse_us center)}"
LEFT_US="${LEFT_US:-$(get_section_value pulse_us left)}"
RIGHT_US="${RIGHT_US:-$(get_section_value pulse_us right)}"
MIN_SAFE_US="${MIN_SAFE_US:-$(get_section_value pulse_us min_safe)}"
MAX_SAFE_US="${MAX_SAFE_US:-$(get_section_value pulse_us max_safe)}"

if [[ -z "${I2C_BUS:-}" ]]; then
  echo "[ERROR] i2c_bus is empty. Set I2C_BUS=<bus> or update configs/pca9685.yaml first."
  exit 1
fi

section "Config"
echo "i2c_bus: $I2C_BUS"
echo "address: $ADDRESS"
echo "frequency_hz: $FREQUENCY_HZ"
echo "test_channel: $TEST_CHANNEL"
echo "safe_range_us: ${MIN_SAFE_US}-${MAX_SAFE_US}"

section "Address Check"
i2cdetect -y "$I2C_BUS"
addr_token="$(printf '%02x' $((ADDRESS)))"
if ! i2cdetect -y "$I2C_BUS" | grep -E "(^|[[:space:]])$addr_token($|[[:space:]])" >/dev/null 2>&1; then
  echo "[ERROR] PCA9685 address $ADDRESS not found on bus $I2C_BUS"
  exit 1
fi

set_pwm_frequency

section "Servo Sequence"
echo "Sequence: center -> left -> right -> center"
set_channel_pulse_us "$TEST_CHANNEL" "$CENTER_US"
sleep 1
set_channel_pulse_us "$TEST_CHANNEL" "$LEFT_US"
sleep 1
set_channel_pulse_us "$TEST_CHANNEL" "$RIGHT_US"
sleep 1
set_channel_pulse_us "$TEST_CHANNEL" "$CENTER_US"
sleep 1

section "Result"
echo "PASS: PCA9685 single-servo smoke test finished."
echo "If the motion is stable, you can manually expand to $MIN_SAFE_US us and $MAX_SAFE_US us."
echo "Log saved to: $LOG_FILE"
