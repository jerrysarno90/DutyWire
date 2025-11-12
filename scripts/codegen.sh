#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export HOME="$REPO_ROOT"
export AMPLIFY_HOME="$REPO_ROOT/.amplify"

echo "[codegen] Running Amplify codegen from $REPO_ROOT"

(
  cd "$REPO_ROOT"
  amplify codegen
)

echo "[codegen] Done."
