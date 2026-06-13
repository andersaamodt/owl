#!/bin/sh

set -eu

stellar_state_root() {
  printf '%s\n' "${STELLAR_STATE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/stellar}"
}

stellar_generated_root() {
  printf '%s\n' "${STELLAR_GENERATED_ROOT:-$(stellar_state_root)/generated}"
}

stellar_mobile_generated_root() {
  printf '%s\n' "${STELLAR_MOBILE_GENERATED_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/stellar-mobile/generated/mobile}"
}
