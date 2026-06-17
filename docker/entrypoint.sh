#!/bin/bash
# =============================================================================
# Container entrypoint — starts Ollama runtime then FastAPI inference API
# =============================================================================
set -euo pipefail

echo "=== Multi-Architecture LLM Pipeline Starting ==="
echo "Environment:    ${ENVIRONMENT:-production}"
echo "Target:         ${DEPLOYMENT_TARGET:-unknown}"
echo "Hardware Type:  ${HARDWARE_TYPE:-cpu}"
echo "Model:          ${MODEL_NAME:-llama3.2:1b}"
echo "Model cache:    ${OLLAMA_MODELS:-/home/appuser/.ollama/models}"

# Start Ollama server in background
echo "Starting Ollama runtime..."
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama..."
for i in $(seq 1 60); do
    if curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        echo "Ollama is ready."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "ERROR: Ollama failed to start within 60 seconds"
        exit 1
    fi
    sleep 2
done

MODEL_NAME="${MODEL_NAME:-llama3.2:1b}"

# Check if model is already in cache (persistent volume / bind mount)
model_is_cached() {
    curl -sf http://127.0.0.1:11434/api/tags | MODEL_NAME="${MODEL_NAME}" python3 -c "
import json, sys, os
target = os.environ.get('MODEL_NAME', '')
data = json.load(sys.stdin)
names = [m.get('name', '') for m in data.get('models', [])]
found = any(target in n or n.startswith(target.split(':')[0]) for n in names)
sys.exit(0 if found else 1)
" 2>/dev/null
}

if model_is_cached; then
    echo "Model ${MODEL_NAME} already cached — skipping download."
    ollama list || true
else
    echo "Model ${MODEL_NAME} not found — downloading (~1.3GB, first time only)."
    echo "Cache path: /home/appuser/.ollama"
    echo "This can take 5-10 minutes. Please wait..."
    ollama pull "${MODEL_NAME}" || {
        echo "WARNING: Model pull failed — will retry at runtime"
    }
fi

# GPU detection log
if command -v nvidia-smi &> /dev/null; then
    echo "GPU detected:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
else
    echo "No GPU detected — running in CPU mode"
fi

# Start FastAPI application
echo "Starting inference API on port 8000..."
exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 1 \
    --log-level info
