#!/bin/sh

set -eu

test_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$test_dir/../.." && pwd -P)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/stellar-ir-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

failures=0

run_case() {
  name=$1
  shift
  if "$@"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

validate_canonical_ir() {
  output=$(cd "$repo_dir" && sh scripts/validate-native-desktop-ir.sh)
  printf '%s\n' "$output" | grep -q '^status=ok$'
}

rejects_unsafe_app_id() {
  unsafe_ir="$tmpdir/unsafe-id.json"
  jq '.app.id = "bad id"' "$repo_dir/app-blueprint/app.ir.yaml" >"$unsafe_ir"
  if sh "$repo_dir/scripts/validate-native-desktop-ir.sh" "$unsafe_ir" "$repo_dir/schemas/native-desktop-ir-v1.json" >"$tmpdir/unsafe-id.out" 2>"$tmpdir/unsafe-id.err"; then
    return 1
  fi
  grep -q 'app.id, app.name, and app.window.title must be render-safe' "$tmpdir/unsafe-id.err"
}

rejects_control_characters() {
  unsafe_ir="$tmpdir/control-char.json"
  jq '.app.mock.messages[0].body = "forged\nbody"' "$repo_dir/app-blueprint/app.ir.yaml" >"$unsafe_ir"
  if sh "$repo_dir/scripts/validate-native-desktop-ir.sh" "$unsafe_ir" "$repo_dir/schemas/native-desktop-ir-v1.json" >"$tmpdir/control-char.out" 2>"$tmpdir/control-char.err"; then
    return 1
  fi
  grep -q 'string values must not contain control characters' "$tmpdir/control-char.err"
}

rejects_stale_node_action() {
  unsafe_ir="$tmpdir/stale-action.json"
  jq '.app.window.toolbar.children[0].action = "missing_action"' "$repo_dir/app-blueprint/app.ir.yaml" >"$unsafe_ir"
  if sh "$repo_dir/scripts/validate-native-desktop-ir.sh" "$unsafe_ir" "$repo_dir/schemas/native-desktop-ir-v1.json" >"$tmpdir/stale-action.out" 2>"$tmpdir/stale-action.err"; then
    return 1
  fi
  grep -q 'every node action must reference an app.actions id' "$tmpdir/stale-action.err"
}

rejects_bad_action_id() {
  unsafe_ir="$tmpdir/bad-action.json"
  jq '.app.actions[0].id = "Refresh Snapshot"' "$repo_dir/app-blueprint/app.ir.yaml" >"$unsafe_ir"
  if sh "$repo_dir/scripts/validate-native-desktop-ir.sh" "$unsafe_ir" "$repo_dir/schemas/native-desktop-ir-v1.json" >"$tmpdir/bad-action.out" 2>"$tmpdir/bad-action.err"; then
    return 1
  fi
  grep -q 'app.actions must be unique snake_case ids' "$tmpdir/bad-action.err"
}

run_case "canonical IR validates" validate_canonical_ir
run_case "unsafe app id rejected" rejects_unsafe_app_id
run_case "control characters rejected" rejects_control_characters
run_case "stale node action rejected" rejects_stale_node_action
run_case "bad action id rejected" rejects_bad_action_id

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "$failures test(s) failed" >&2
  exit 1
fi

printf '%s\n' "5/5 native IR contract tests passed"
