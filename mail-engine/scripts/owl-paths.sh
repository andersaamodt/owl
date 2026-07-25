#!/bin/sh
set -eu

owl_build_state_dir() {
  printf '%s\n' "${OWL_BUILD_STATE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/stellar/mail-engine}"
}

owl_cargo_target_dir() {
  printf '%s\n' "$(owl_build_state_dir)/cargo-target"
}

owl_compiled_binary_path() {
  binary_name=${1:?binary name required}
  profile=${2:-debug}
  build_target=${3-}
  if [ -n "$build_target" ]; then
    printf '%s\n' "$(owl_cargo_target_dir)/$build_target/$profile/$binary_name"
    return 0
  fi
  printf '%s\n' "$(owl_cargo_target_dir)/$profile/$binary_name"
}
