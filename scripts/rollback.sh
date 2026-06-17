#!/usr/bin/env bash
# =============================================================================
# Rollback Script
#
# Reverts to a previous deployment manifest.
# Used when validation fails or production issues are detected.
# =============================================================================
set -euo pipefail

MANIFEST_ID="${1:-}"
MANIFESTS_DIR="${MANIFESTS_DIR:-manifests}"

if [[ -z "${MANIFEST_ID}" ]]; then
  echo "Usage: $0 <manifest-id>"
  echo "Available manifests:"
  ls -1 "${MANIFESTS_DIR}"/*.json 2>/dev/null | grep -v latest || echo "  (none)"
  exit 1
fi

MANIFEST_FILE="${MANIFESTS_DIR}/${MANIFEST_ID}.json"
[[ -f "${MANIFEST_FILE}" ]] || { echo "Manifest not found: ${MANIFEST_FILE}"; exit 1; }

echo "=== Rolling back to: ${MANIFEST_ID} ==="

CONTAINER_IMAGE=$(jq -r '.container_image' "${MANIFEST_FILE}")
DEPLOYMENT_TARGET=$(jq -r '.deployment_target' "${MANIFEST_FILE}")
HARDWARE_TYPE=$(jq -r '.hardware_type' "${MANIFEST_FILE}")
MODEL_VERSION=$(jq -r '.model_version' "${MANIFEST_FILE}")
API_ENDPOINT=$(jq -r '.api_endpoint' "${MANIFEST_FILE}")

echo "Target:    ${DEPLOYMENT_TARGET}"
echo "Hardware:  ${HARDWARE_TYPE}"
echo "Model:     ${MODEL_VERSION}"
echo "Image:     ${CONTAINER_IMAGE}"

# Re-deploy previous image via Ansible
export CONTAINER_IMAGE MODEL_VERSION HARDWARE_TYPE DEPLOYMENT_TARGET
ansible-playbook \
  -i "ansible/inventory/${DEPLOYMENT_TARGET%%-*}.yml" \
  ansible/playbooks/site.yml \
  --tags deploy \
  -e "container_image=${CONTAINER_IMAGE}" \
  -e "model_version=${MODEL_VERSION}" \
  -e "hardware_type=${HARDWARE_TYPE}" \
  -e "force_image_pull=true"

# Validate rollback
./scripts/validate-deployment.sh "${API_ENDPOINT}"

# Record rollback manifest
export VALIDATION_STATUS=rollback
./scripts/generate-manifest.sh

echo "=== Rollback complete ==="
