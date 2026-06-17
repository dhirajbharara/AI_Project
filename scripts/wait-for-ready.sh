#!/usr/bin/env bash
# Wait until the LLM API is ready (model loaded and serving).
set -euo pipefail

API_ENDPOINT="${1:-http://localhost:8000}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-900}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"

echo "Waiting for ${API_ENDPOINT}/ready (max ${MAX_WAIT_SECONDS}s)..."

START=$(date +%s)
while true; do
  if RESPONSE=$(curl -sf --max-time 10 "${API_ENDPOINT}/ready" 2>/dev/null); then
    if echo "${RESPONSE}" | grep -q '"model_available":true'; then
      ELAPSED=$(( $(date +%s) - START ))
      echo "Ready after ${ELAPSED}s"
      exit 0
    fi
  fi

  ELAPSED=$(( $(date +%s) - START ))
  if [ "${ELAPSED}" -ge "${MAX_WAIT_SECONDS}" ]; then
    echo "ERROR: Timed out waiting for ${API_ENDPOINT}/ready"
    exit 1
  fi

  echo "  Still starting... (${ELAPSED}s elapsed — first run may download ~1.3GB model)"
  sleep "${INTERVAL_SECONDS}"
done
