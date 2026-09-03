#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf 'bootstrap.sh is a Phase 1 stub for %s; Phase 5 will wire installation and configuration.\n' "$repo_dir"
