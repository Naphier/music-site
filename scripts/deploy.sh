#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

: "${S3_BUCKET_NAME:?S3_BUCKET_NAME is required}"
: "${S3_REGION:?S3_REGION is required}"
: "${TRACKS_PREFIX:?TRACKS_PREFIX is required (example: tracks)}"
: "${ENABLE_MOCK_MODE:?ENABLE_MOCK_MODE is required (true/false)}"

DEPLOY_PREFIX="${DEPLOY_PREFIX:-dev}"
HEADER_CONTENT_FILE="${HEADER_CONTENT_FILE:-headerContent.html}"

if [[ ! -f "$HEADER_CONTENT_FILE" ]]; then
  echo "Header content file not found: $HEADER_CONTENT_FILE" >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required but not found in PATH." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cp index.html app.js styles.css "$HEADER_CONTENT_FILE" "$TMP_DIR/"

export TMP_DIR S3_BUCKET_NAME S3_REGION TRACKS_PREFIX ENABLE_MOCK_MODE HEADER_CONTENT_FILE
python3 <<'PY'
import os
from pathlib import Path
import re

work = Path(os.environ["TMP_DIR"])
index_file = work / "index.html"
app_file = work / "app.js"
header_file = work / os.environ["HEADER_CONTENT_FILE"]

bucket = os.environ["S3_BUCKET_NAME"]
region = os.environ["S3_REGION"]
tracks_prefix = os.environ["TRACKS_PREFIX"].strip("/")
mock_mode = os.environ["ENABLE_MOCK_MODE"].lower()
if mock_mode not in {"true", "false"}:
    raise SystemExit("ENABLE_MOCK_MODE must be 'true' or 'false'")

prefix_for_js = f"{tracks_prefix}/" if tracks_prefix else ""

index = index_file.read_text(encoding="utf-8")
header = header_file.read_text(encoding="utf-8").strip()
index = re.sub(
    r'(<header class="artist-header">)([\s\S]*?)(</header>)',
    lambda m: f'{m.group(1)}\\n{header}\\n      {m.group(3)}',
    index,
    count=1,
)
index_file.write_text(index, encoding="utf-8")

app = app_file.read_text(encoding="utf-8")
app = re.sub(r"bucketName:\s*'[^']*'", f"bucketName: '{bucket}'", app, count=1)
app = re.sub(r"region:\s*'[^']*'", f"region: '{region}'", app, count=1)
app = re.sub(r"prefix:\s*'[^']*'", f"prefix: '{prefix_for_js}'", app, count=1)
app = re.sub(r"enableMockMode:\s*(true|false)", f"enableMockMode: {mock_mode}", app, count=1)
app_file.write_text(app, encoding="utf-8")
PY

echo "Deploying static site to s3://${S3_BUCKET_NAME}/${DEPLOY_PREFIX}/"
aws s3 sync "$TMP_DIR" "s3://${S3_BUCKET_NAME}/${DEPLOY_PREFIX}/" \
  --region "$S3_REGION" \
  --delete \
  --exclude "$HEADER_CONTENT_FILE" \
  --exclude "tracks/*"

echo "Deployment complete."
