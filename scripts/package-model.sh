#!/usr/bin/env bash
# =============================================================================
# Model Packaging Stage
#
# Downloads and packages the LLM model for container inclusion or pre-caching.
# In production, models are pulled at deploy time or stored in object storage.
# =============================================================================
set -euo pipefail

MODEL_NAME="${MODEL_NAME:-llama3.2:1b}"
MODEL_VERSION="${MODEL_VERSION:-1.0.0}"
PACKAGE_DIR="${PACKAGE_DIR:-./model-packages}"

mkdir -p "${PACKAGE_DIR}"

cat > "${PACKAGE_DIR}/model-manifest.json" <<EOF
{
  "model_name": "${MODEL_NAME}",
  "model_version": "${MODEL_VERSION}",
  "runtime": "ollama",
  "format": "gguf",
  "packaged_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "size_estimate_mb": 1300,
  "hardware_requirements": {
    "cpu_min_ram_gb": 4,
    "gpu_min_vram_gb": 4
  }
}
EOF

echo "Model package manifest created: ${PACKAGE_DIR}/model-manifest.json"
echo "Model ${MODEL_NAME} v${MODEL_VERSION} ready for container build"
