#!/usr/bin/env bash
# Hardware detection script — used by CI/CD and local testing
set -euo pipefail

if command -v nvidia-smi &>/dev/null; then
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  if [[ -n "${GPU_NAME}" ]]; then
    echo "gpu"
    echo "GPU: ${GPU_NAME}" >&2
    nvidia-smi --query-gpu=memory.total,driver_version --format=csv,noheader >&2
    exit 0
  fi
fi

echo "cpu"
echo "No GPU detected — CPU mode" >&2
nproc >&2 && echo "CPU cores: $(nproc)" >&2
