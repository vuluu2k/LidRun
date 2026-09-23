#!/usr/bin/env bash
set -euo pipefail

FILE="${1:?Usage: $0 <file>}"
[[ -f "$FILE" ]] || { echo "File not found: $FILE" >&2; exit 1; }

response="$(curl --fail-with-body --silent --show-error --max-time 120 \
  -H 'Accept: application/json' \
  -F "file=@$FILE;type=application/x-apple-diskimage" \
  https://api.webcake.io/external/upload_file)"

python3 -c 'import json,sys
payload=json.load(sys.stdin)
url=payload.get("data")
if payload.get("success") is not True or not isinstance(url, str):
    raise SystemExit(f"Upload failed: {payload}")
print(url)' <<<"$response"
