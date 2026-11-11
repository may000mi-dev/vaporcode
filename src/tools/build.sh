#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

OUT_DIR="${1:-}"
if [ -z "$OUT_DIR" ]; then
  if [ -d /sdcard/Download ]; then
    OUT_DIR=/sdcard/Download
  else
    OUT_DIR="$ROOT/build"
  fi
fi
OUT="$OUT_DIR/vaporcode.love"

echo "1/4 Verificando sintaxis..."
find . -name '*.lua' -print0 | xargs -0 -n1 luac -p
echo "Sintaxis OK"

echo "2/4 Ejecutando tests unitarios..."
sh src/tools/test_all.sh

echo "3/4 Empaquetando .love..."
mkdir -p "$OUT_DIR"
rm -f "$OUT"
zip -r -D "$OUT" conf.lua main.lua src -x 'src/tools/*'

echo "4/4 Verificando paquete..."
unzip -t "$OUT"

echo "Paquete listo: $OUT"
