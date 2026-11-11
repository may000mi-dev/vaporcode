#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

LUA_BIN="${LUA_BIN:-}"
if [ -z "$LUA_BIN" ]; then
  if command -v lua >/dev/null 2>&1; then
    LUA_BIN=lua
  elif command -v luajit >/dev/null 2>&1; then
    LUA_BIN=luajit
  else
    echo "Error: se necesita lua o luajit para ejecutar los tests." >&2
    exit 1
  fi
fi

for test in src/tools/test_*.lua; do
  [ -e "$test" ] || continue
  echo "→ $test"
  "$LUA_BIN" "$test"
done

echo "Tests OK"
