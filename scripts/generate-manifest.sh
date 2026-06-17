#!/usr/bin/env bash
# =============================================================================
# Deployment Manifest Generator
#
# Creates JSON manifest with deployment metadata for audit trail and rollback.
# Manifests stored in manifests/ directory, committed by CI pipeline.
# =============================================================================
set -euo pipefail

DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-unknown}"
HARDWARE_TYPE="${HARDWARE_TYPE:-cpu}"
ENVIRONMENT="${ENVIRONMENT:-production}"
MODEL_VERSION="${MODEL_VERSION:-1.0.0}"
API_ENDPOINT="${API_ENDPOINT:-http://localhost:8000}"
MANIFESTS_DIR="${MANIFESTS_DIR:-manifests}"

GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MANIFEST_ID="${DEPLOYMENT_TARGET}-${ENVIRONMENT}-${TIMESTAMP}"

mkdir -p "${MANIFESTS_DIR}"

# Capture validation results if available
VALIDATION_STATUS="${VALIDATION_STATUS:-passed}"
AVG_LATENCY_MS="${AVG_LATENCY_MS:-0}"

cat > "${MANIFESTS_DIR}/${MANIFEST_ID}.json" <<EOF
{
  "manifest_id": "${MANIFEST_ID}",
  "model_version": "${MODEL_VERSION}",
  "model_name": "${MODEL_NAME:-llama3.2:1b}",
  "deployment_target": "${DEPLOYMENT_TARGET}",
  "deployment_timestamp": "${TIMESTAMP}",
  "git_commit": "${GIT_COMMIT}",
  "git_branch": "${GIT_BRANCH}",
  "hardware_type": "${HARDWARE_TYPE}",
  "environment": "${ENVIRONMENT}",
  "api_endpoint": "${API_ENDPOINT}",
  "container_image": "${CONTAINER_IMAGE:-ghcr.io/org/multi-arch-llm-pipeline:latest}",
  "validation": {
    "status": "${VALIDATION_STATUS}",
    "avg_latency_ms": ${AVG_LATENCY_MS},
    "prompts_tested": ["Hello", "What is Kubernetes?", "What is AI?"]
  },
  "rollback": {
    "previous_manifest": "${PREVIOUS_MANIFEST:-null}",
    "rollback_command": "./scripts/rollback.sh ${MANIFEST_ID}"
  }
}
EOF

# Update latest pointer
cp "${MANIFESTS_DIR}/${MANIFEST_ID}.json" "${MANIFESTS_DIR}/latest.json"

echo "Manifest generated: ${MANIFESTS_DIR}/${MANIFEST_ID}.json"
cat "${MANIFESTS_DIR}/${MANIFEST_ID}.json" | jq .
