#!/usr/bin/env bash

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
BUILD_DIR="${AGENTVILLE_WEB_BUILD_DIR:-$PROJECT_DIR/build/web}"
PUBLISH_DIR="${AGENTVILLE_WEB_PUBLISH_DIR:-$PROJECT_DIR/deploy/vercel}"

case "$PUBLISH_DIR" in
	"$PROJECT_DIR"/deploy/*)
		;;
	*)
		printf 'Refusing Web publish directory outside godot/deploy: %s\n' "$PUBLISH_DIR" >&2
		exit 2
		;;
esac

if ! command -v rsync >/dev/null 2>&1; then
	printf 'rsync is required to prepare the reviewed Web artifact.\n' >&2
	exit 2
fi

AGENTVILLE_WEB_OUTPUT_DIR="$BUILD_DIR" "$TOOLS_DIR/export_web.sh"

mkdir -p "$PUBLISH_DIR"
COPYFILE_DISABLE=1 rsync \
	-a \
	--delete \
	--exclude='vercel.json' \
	"$BUILD_DIR/" \
	"$PUBLISH_DIR/"

for required_file in index.html index.js index.wasm index.pck; do
	if [[ ! -s "$PUBLISH_DIR/$required_file" ]]; then
		printf 'Reviewed Web artifact is missing required file: %s\n' "$PUBLISH_DIR/$required_file" >&2
		exit 1
	fi
done

if [[ -e "$PUBLISH_DIR/vercel.json" ]]; then
	printf 'Nested Vercel configuration must not be published as a static file.\n' >&2
	exit 1
fi

(
	cd "$PUBLISH_DIR"
	LC_ALL=C shasum -a 256 index.html index.js index.wasm index.pck > artifact-sha256.txt
)

find "$PUBLISH_DIR" -type f -name '._*' -delete

printf 'Reviewed AgentVille Web artifact ready: %s\n' "$PUBLISH_DIR"
du -sh "$PUBLISH_DIR"
