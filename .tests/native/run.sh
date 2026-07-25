#!/bin/sh

set -eu

test_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

sh "$test_dir/test-backend-contract.sh"

if [ -f "$test_dir/test-native-ir-contract.sh" ]; then
  sh "$test_dir/test-native-ir-contract.sh"
fi

if [ -f "$test_dir/test-render-native-desktop.sh" ]; then
  sh "$test_dir/test-render-native-desktop.sh"
fi

if [ -f "$test_dir/test-native-mobile.sh" ]; then
  sh "$test_dir/test-native-mobile.sh"
fi

if [ -f "$test_dir/test-theurgy-contract.sh" ]; then
  sh "$test_dir/test-theurgy-contract.sh"
fi

if [ -f "$test_dir/test-mail-engine-bundle.sh" ]; then
  sh "$test_dir/test-mail-engine-bundle.sh"
fi

printf '%s\n' "native test suite passed"
