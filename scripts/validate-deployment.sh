#!/usr/bin/env bash
# =============================================================================
# Deployment Validation Script
#
# Runs after every deployment. Pipeline FAILS if any check fails.
# Validates: HTTP response, latency, model availability
# =============================================================================
set -euo pipefail

API_ENDPOINT="${1:-http://localhost:8000}"
MAX_LATENCY_MS="${MAX_LATENCY_MS:-120000}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"

PROMPTS=("Hello" "What is Kubernetes?" "What is AI?")

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${GREEN}[VALIDATE]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

json_get() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r "$key"
  else
    python3 -c 'import json,sys
data=json.load(sys.stdin)
path=sys.argv[1].lstrip(".")
for part in path.split("."):
    if not part:
        continue
    data=data.get(part, None) if isinstance(data, dict) else None
if data is None:
    print("")
elif isinstance(data, bool):
    print(str(data).lower())
else:
    print(data)' "$key"
  fi
}

log "=== Deployment Validation ==="
log "Endpoint: ${API_ENDPOINT}"

if ! command -v jq >/dev/null 2>&1; then
  log "jq not found; using python3 JSON parser fallback"
fi

# --- Check 1: Health endpoint ---
log "Checking /health..."
HEALTH_STATUS=$(curl -sf --max-time 10 "${API_ENDPOINT}/health" | json_get '.status' 2>/dev/null || echo "error")
[[ "${HEALTH_STATUS}" == "healthy" ]] || fail "Health check failed: ${HEALTH_STATUS}"
log "Health check passed"

# --- Check 2: Readiness (model availability) ---
log "Checking /ready (model availability)..."
READY_RESPONSE=$(curl -sf --max-time 30 "${API_ENDPOINT}/ready" 2>/dev/null) || fail "Readiness check failed — model not available"
MODEL_AVAILABLE=$(echo "${READY_RESPONSE}" | json_get '.model_available')
[[ "${MODEL_AVAILABLE}" == "true" ]] || fail "Model not available"
log "Model availability confirmed"

# --- Check 3: Inference prompts ---
TOTAL_LATENCY=0
PROMPT_COUNT=0

for PROMPT in "${PROMPTS[@]}"; do
  log "Testing prompt: \"${PROMPT}\""

  START_MS=$(date +%s%3N)
  RESPONSE=$(curl -sf --max-time "${TIMEOUT_SECONDS}" \
    -X POST "${API_ENDPOINT}/infer" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"${PROMPT}\"}" 2>/dev/null) || fail "Inference failed for prompt: ${PROMPT}"

  END_MS=$(date +%s%3N)
  LATENCY=$((END_MS - START_MS))

  RESPONSE_TEXT=$(echo "${RESPONSE}" | json_get '.response')
  REPORTED_LATENCY=$(echo "${RESPONSE}" | json_get '.latency_ms')

  [[ -n "${RESPONSE_TEXT}" ]] || fail "Empty response for prompt: ${PROMPT}"
  [[ "${LATENCY}" -lt "${MAX_LATENCY_MS}" ]] || fail "Latency ${LATENCY}ms exceeds max ${MAX_LATENCY_MS}ms for: ${PROMPT}"

  log "  Response (${REPORTED_LATENCY}ms): ${RESPONSE_TEXT:0:80}..."
  TOTAL_LATENCY=$((TOTAL_LATENCY + LATENCY))
  PROMPT_COUNT=$((PROMPT_COUNT + 1))
done

AVG_LATENCY=$((TOTAL_LATENCY / PROMPT_COUNT))
log "Average latency: ${AVG_LATENCY}ms across ${PROMPT_COUNT} prompts"

# --- Check 4: Metrics endpoint ---
log "Checking /metrics..."
METRICS=$(curl -sf --max-time 10 "${API_ENDPOINT}/metrics" 2>/dev/null) || fail "Metrics endpoint unreachable"
echo "${METRICS}" | grep -q "llm_inference_requests_total" || fail "Expected Prometheus metrics not found"
log "Metrics endpoint verified"

log "=== All validation checks passed ==="
exit 0
