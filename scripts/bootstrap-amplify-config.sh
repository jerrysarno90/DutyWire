#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI_CONTEXT="${CI:-}"
if [[ -z "$CI_CONTEXT" && -n "${XCODE_CLOUD:-}" ]]; then
  CI_CONTEXT="1"
fi

missing=()

decode_payload() {
  local payload="$1"
  local target="$2"

  if [[ "$payload" =~ ^[[:space:]]*\{ ]]; then
    printf '%s' "$payload" > "$target"
  else
    TARGET_PATH="$target" PAYLOAD_DATA="$payload" python3 <<'PY'
import base64
import os

payload = os.environ["PAYLOAD_DATA"]
target = os.environ["TARGET_PATH"]

with open(target, "wb") as fh:
    fh.write(base64.b64decode(payload.encode("utf-8")))
PY
  fi
}

ensure_file() {
  local target="$1"
  local env_var="$2"
  local label="$3"

  if [[ -f "$target" ]]; then
    echo "[amplify-config] Using existing ${label} at ${target}"
    return
  fi

  local payload="${!env_var:-}"
  if [[ -z "$payload" ]]; then
    missing+=("${label} (set ${env_var})")
    return
  fi

  mkdir -p "$(dirname "$target")"
  decode_payload "$payload" "$target"
  chmod 600 "$target" 2>/dev/null || true
  echo "[amplify-config] Created ${label} from ${env_var}"
}

ensure_file "$ROOT_DIR/awsconfiguration.json" "DUTYWIRE_AWSCONFIG_BASE64" "awsconfiguration.json"
ensure_file "$ROOT_DIR/amplify_outputs.json" "DUTYWIRE_AMPLIFY_OUTPUTS_BASE64" "amplify_outputs.json"

if [[ ${#missing[@]} -gt 0 ]]; then
  message="Missing required Amplify config files: ${missing[*]}"
  if [[ -n "$CI_CONTEXT" ]]; then
    echo "::error::${message}" >&2
    exit 1
  else
    echo "[amplify-config] Warning: ${message}" >&2
  fi
fi
