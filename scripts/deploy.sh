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

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required but not found in PATH." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Stage deployable site files while excluding repo/CI metadata and tooling files.
rsync -a ./ "$TMP_DIR/" \
  --exclude ".git/" \
  --exclude ".github/" \
  --exclude "scripts/" \
  --exclude "README.md" \
  --exclude ".env" \
  --exclude ".env.*" \
  --exclude ".gitignore"

export TMP_DIR S3_BUCKET_NAME S3_REGION TRACKS_PREFIX ENABLE_MOCK_MODE HEADER_CONTENT_FILE
python3 <<'PY'
import os
from pathlib import Path

work = Path(os.environ["TMP_DIR"])
index_file = work / "index.html"
app_file = work / "app.js"
header_file = work / os.environ["HEADER_CONTENT_FILE"]

if not index_file.exists():
    raise SystemExit("index.html was not found in staged files")
if not app_file.exists():
    raise SystemExit("app.js was not found in staged files")
if not header_file.exists():
    raise SystemExit(f"{header_file.name} was not found in staged files")

bucket = os.environ["S3_BUCKET_NAME"]
region = os.environ["S3_REGION"]
tracks_prefix = os.environ["TRACKS_PREFIX"].strip("/")
mock_mode = os.environ["ENABLE_MOCK_MODE"].lower()
if mock_mode not in {"true", "false"}:
    raise SystemExit("ENABLE_MOCK_MODE must be 'true' or 'false'")

prefix_for_js = f"{tracks_prefix}/" if tracks_prefix else ""

index = index_file.read_text(encoding="utf-8")
start_token = "<!-- __ARTIST_HEADER_START__ -->"
end_token = "<!-- __ARTIST_HEADER_END__ -->"
start_idx = index.find(start_token)
end_idx = index.find(end_token)
if start_idx == -1 or end_idx == -1 or end_idx <= start_idx:
    raise SystemExit("Could not find valid artist header placeholder tokens in index.html")

start_content = start_idx + len(start_token)
header = header_file.read_text(encoding="utf-8").strip()
index = index[:start_content] + "\n" + header + "\n        " + index[end_idx:]
index_file.write_text(index, encoding="utf-8")

app = app_file.read_text(encoding="utf-8")
replacements = {
    "__DEPLOY_S3_BUCKET_NAME__": bucket,
    "__DEPLOY_S3_REGION__": region,
    "__DEPLOY_TRACKS_PREFIX__": prefix_for_js,
    "__DEPLOY_ENABLE_MOCK_MODE__": mock_mode,
}
for token, value in replacements.items():
    count = app.count(token)
    if count == 0:
        raise SystemExit(f"Missing placeholder token in app.js: {token}")
    app = app.replace(token, value)
app_file.write_text(app, encoding="utf-8")
PY

echo "Deploying static site to s3://${S3_BUCKET_NAME}/${DEPLOY_PREFIX}/"
aws s3 sync "$TMP_DIR" "s3://${S3_BUCKET_NAME}/${DEPLOY_PREFIX}/" \
  --region "$S3_REGION" \
  --delete \
  --exclude "$HEADER_CONTENT_FILE" \
  --exclude "tracks/*"

echo "Deployment complete."
