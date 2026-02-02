#!/bin/sh
set -eu

if ! command -v owl >/dev/null 2>&1; then
  printf 'error: owl binary not found on PATH\n' >&2
  exit 1
fi

exec owl configure "$@"
