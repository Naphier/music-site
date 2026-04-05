#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_BIN="$(mktemp -d)"
LOG_FILE="$(mktemp)"
cleanup() {
  rm -rf "$TMP_BIN"
  rm -f "$LOG_FILE"
  rm -f "${TEST_HEADER_FILE:-}"
}
trap cleanup EXIT

cat > "$TMP_BIN/aws" <<'AWS'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" != "s3" || "$2" != "sync" ]]; then
  echo "Unexpected aws invocation: $*" >&2
  exit 1
fi

SOURCE_DIR="$3"
DEST="$4"

[[ -f "$SOURCE_DIR/index.html" ]] || { echo "Missing index.html in staged output" >&2; exit 1; }
[[ -f "$SOURCE_DIR/app.js" ]] || { echo "Missing app.js in staged output" >&2; exit 1; }

grep -q '<h1>Injected Header</h1>' "$SOURCE_DIR/index.html" || {
  echo "Header content was not injected" >&2
  exit 1
}

grep -q "bucketName: 'test-bucket'" "$SOURCE_DIR/app.js" || {
  echo "bucketName was not written to app.js" >&2
  exit 1
}
grep -q "region: 'us-west-2'" "$SOURCE_DIR/app.js" || {
  echo "region was not written to app.js" >&2
  exit 1
}
grep -q "prefix: 'tracks/'" "$SOURCE_DIR/app.js" || {
  echo "tracks prefix was not written to app.js" >&2
  exit 1
}
grep -q "enableMockMode: false" "$SOURCE_DIR/app.js" || {
  echo "enableMockMode was not written to app.js" >&2
  exit 1
}

if [[ "$DEST" != "s3://test-bucket/dev/" ]]; then
  echo "Unexpected destination: $DEST" >&2
  exit 1
fi

echo "mock aws sync verified"
AWS
chmod +x "$TMP_BIN/aws"

TEST_HEADER_FILE="test-headerContent.html"
cat > "$TEST_HEADER_FILE" <<'HTML'
<h1>Injected Header</h1>
<p>Injected by test script.</p>
HTML

PATH="$TMP_BIN:$PATH" \
S3_BUCKET_NAME="test-bucket" \
S3_REGION="us-west-2" \
TRACKS_PREFIX="tracks" \
DEPLOY_PREFIX="dev" \
ENABLE_MOCK_MODE="false" \
HEADER_CONTENT_FILE="$TEST_HEADER_FILE" \
./scripts/deploy.sh | tee "$LOG_FILE"

rm -f "$TEST_HEADER_FILE"

grep -q 'Deployment complete.' "$LOG_FILE" || {
  echo "Deployment script did not finish successfully" >&2
  exit 1
}

echo "deploy test passed"
