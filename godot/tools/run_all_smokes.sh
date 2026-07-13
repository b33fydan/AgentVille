#!/usr/bin/env bash

set -uo pipefail

GODOT="${GODOT:-/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TOOLS_DIR/.." && pwd)"

if [[ ! -x "$GODOT" ]]; then
	printf 'Godot executable not found: %s\n' "$GODOT" >&2
	exit 2
fi

printf '%-52s %s\n' 'SMOKE' 'RESULT'
printf '%-52s %s\n' '-----' '------'

passed=0
failed=0
total=0

for smoke_path in "$TOOLS_DIR"/smoke_*.gd; do
	if [[ ! -f "$smoke_path" ]]; then
		continue
	fi

	smoke_name="$(basename "$smoke_path" .gd)"
	log_path="$(mktemp "/tmp/agentville-${smoke_name}.log.XXXXXX")"
	((total += 1))

	"$GODOT" --headless --path "$PROJECT_DIR" --script "res://tools/${smoke_name}.gd" >"$log_path" 2>&1
	exit_code=$?
	if [[ $exit_code -eq 0 ]] && ! grep -Eq 'SCRIPT ERROR|ERROR:' "$log_path"; then
		printf '%-52s %s\n' "$smoke_name" 'PASS'
		((passed += 1))
	else
		printf '%-52s %s\n' "$smoke_name" 'FAIL'
		printf '  log: %s\n' "$log_path"
		printf '  exit: %s\n' "$exit_code"
		sed -n '1,240p' "$log_path"
		((failed += 1))
	fi

	if [[ $exit_code -eq 0 ]] && ! grep -Eq 'SCRIPT ERROR|ERROR:' "$log_path"; then
		rm -f "$log_path"
	fi
done

printf '\nSummary: %s/%s passed, %s failed.\n' "$passed" "$total" "$failed"
if [[ $failed -ne 0 ]]; then
	exit 1
fi
