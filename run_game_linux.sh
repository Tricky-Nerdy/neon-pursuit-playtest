#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
for engine in godot4 godot Godot_v4.7.2-stable_linux.x86_64; do
    if command -v "$engine" >/dev/null 2>&1; then
        exec "$engine" --path "$project_dir"
    fi
done
echo "Install Godot 4.7.2 or export the Linux Desktop preset, then run the exported NeonPursuit.x86_64." >&2
exit 1
