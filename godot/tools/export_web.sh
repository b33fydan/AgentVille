#!/usr/bin/env bash

set -euo pipefail

GODOT="${GODOT:-/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
OUTPUT_DIR="${AGENTVILLE_WEB_OUTPUT_DIR:-$PROJECT_DIR/build/web}"
OUTPUT_HTML="$OUTPUT_DIR/index.html"
LOG_PATH="${AGENTVILLE_WEB_LOG_PATH:-${TMPDIR:-/tmp}/agentville-web-export.log}"

if [[ ! -x "$GODOT" ]]; then
	printf 'Godot executable not found: %s\n' "$GODOT" >&2
	exit 2
fi

case "$OUTPUT_DIR" in
	/|"$PROJECT_DIR"|"$PROJECT_DIR/build")
		printf 'Refusing unsafe Web output directory: %s\n' "$OUTPUT_DIR" >&2
		exit 2
		;;
esac

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
rm -f "$LOG_PATH"

"$GODOT" \
	--headless \
	--log-file "$LOG_PATH" \
	--path "$PROJECT_DIR" \
	--export-release "Web" \
	"$OUTPUT_HTML"

cp "$PROJECT_DIR/web/vercel.json" "$OUTPUT_DIR/vercel.json"
chmod -R u=rwX,go=rX "$OUTPUT_DIR"

for required_file in index.html index.js index.wasm index.pck vercel.json; do
	if [[ ! -s "$OUTPUT_DIR/$required_file" ]]; then
		printf 'Web export is missing required file: %s\n' "$OUTPUT_DIR/$required_file" >&2
		exit 1
	fi
done

if grep -aFq 'Storing File: res://assets/megavoxpack_local_preview/' "$LOG_PATH"; then
	printf 'Licensed local MEGAVOX assets leaked into the public Web package.\n' >&2
	exit 1
fi

printf 'AgentVille Web export ready: %s\n' "$OUTPUT_HTML"
du -sh "$OUTPUT_DIR"
