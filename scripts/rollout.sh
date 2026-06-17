#!/usr/bin/env bash
# =============================================================================
# Rolling Deployment (Blue-Green / Canary)
#
# Deploys new version to one node at a time, validates each before proceeding.
# If validation fails on any node, triggers automatic rollback.
# =============================================================================
set -euo pipefail

INVENTORY="${1:-ansible/inventory/aws.yml}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-ghcr.io/org/multi-arch-llm-pipeline:latest}"
MODEL_VERSION="${MODEL_VERSION:-1.0.0}"

echo "=== Rolling Deployment ==="
echo "Inventory: ${INVENTORY}"
echo "Image:     ${CONTAINER_IMAGE}"

HOSTS=$(ansible-inventory -i "${INVENTORY}" --list 2>/dev/null | jq -r '.. | .hosts? // empty | .[]' 2>/dev/null || echo "")

if [[ -z "${HOSTS}" ]]; then
  echo "No hosts found in inventory — running full playbook"
  ansible-playbook -i "${INVENTORY}" ansible/playbooks/site.yml \
    -e "container_image=${CONTAINER_IMAGE}" \
    -e "model_version=${MODEL_VERSION}"
  exit 0
fi

PREVIOUS_MANIFEST=""
if [[ -f manifests/latest.json ]]; then
  PREVIOUS_MANIFEST=$(jq -r '.manifest_id' manifests/latest.json)
fi

for HOST in ${HOSTS}; do
  echo "--- Deploying to: ${HOST} ---"

  ansible-playbook -i "${INVENTORY}" ansible/playbooks/site.yml \
    --limit "${HOST}" \
    -e "container_image=${CONTAINER_IMAGE}" \
    -e "model_version=${MODEL_VERSION}" \
    -e "force_image_pull=true" \
    --tags deploy || {
      echo "Deployment failed on ${HOST} — initiating rollback"
      [[ -n "${PREVIOUS_MANIFEST}" ]] && ./scripts/rollback.sh "${PREVIOUS_MANIFEST}"
      exit 1
    }

  HOST_IP=$(ansible-inventory -i "${INVENTORY}" --host "${HOST}" 2>/dev/null | jq -r '.ansible_host' || echo "localhost")
  ./scripts/validate-deployment.sh "http://${HOST_IP}:8000" || {
    echo "Validation failed on ${HOST} — initiating rollback"
    [[ -n "${PREVIOUS_MANIFEST}" ]] && ./scripts/rollback.sh "${PREVIOUS_MANIFEST}"
    exit 1
  }

  echo "Node ${HOST} deployed and validated successfully"
done

echo "=== Rolling deployment complete ==="
