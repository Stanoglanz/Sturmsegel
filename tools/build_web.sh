#!/usr/bin/env bash
# Baut die Browser-Version: Godot-Export, Engine gepackt (gzip), eigene Startseite.
# Aufruf: tools/build_web.sh <godot-binary> <zielordner>
set -euo pipefail
G="$1"; OUT="$2"
cd "$(dirname "$0")/.."
mkdir -p build/web "$OUT"
"$G" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1
rm -f "$OUT"/*
cp build/web/index.js build/web/index.audio.worklet.js "$OUT/"
gzip -9 -c build/web/index.wasm > "$OUT/engine.wasm"
gzip -9 -c build/web/index.pck > "$OUT/spieldaten.wasm"
WS=$(stat -c %s build/web/index.wasm); PS=$(stat -c %s build/web/index.pck)
sed -e "s/const WASM_SIZE = [0-9]*;/const WASM_SIZE = $WS;/" \
    -e "s/\"index.pck\":[0-9]*/\"index.pck\":$PS/" -e "s/\"index.wasm\":[0-9]*/\"index.wasm\":$WS/" web/index.html > "$OUT/index.html"
ls -la "$OUT"
