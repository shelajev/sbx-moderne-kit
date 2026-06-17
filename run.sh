#!/usr/bin/env bash
set -euo pipefail

sandbox_name="${1:-moderne-current}"
agent="${2:-claude}"
workspace="${3:-.}"

sbx create --name "$sandbox_name" --kit . "$agent" "$workspace" 2>/dev/null || true
sbx run --kit . "$sandbox_name"
