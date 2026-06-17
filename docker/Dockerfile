# =============================================================================
# Multi-Architecture LLM Pipeline — Production Container Image
# =============================================================================
# Why a single Dockerfile for all targets?
# - "Build once, deploy anywhere" — same image on AWS, Azure, on-prem
# - Hardware differences handled via environment variables at runtime
# - Ollama auto-detects CUDA when GPU drivers are present on the host
# =============================================================================

FROM ollama/ollama:latest AS ollama-base

FROM python:3.12-slim-bookworm

LABEL org.opencontainers.image.title="multi-arch-llm-pipeline"
LABEL org.opencontainers.image.description="Enterprise LLM inference — CPU/GPU, cloud/on-prem"
LABEL org.opencontainers.image.version="1.0.0"

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Copy Ollama binary + runtime from official image.
# Ollama resolves llama-server from /usr/local/lib/ollama and /usr/local/bin.
COPY --from=ollama-base /bin/ollama /usr/local/bin/ollama
COPY --from=ollama-base /usr/lib/ollama /usr/local/lib/ollama
RUN ln -sf /usr/local/lib/ollama/llama-server /usr/local/bin/llama-server

ENV OLLAMA_LIBRARY_PATH=/usr/local/lib/ollama
ENV LD_LIBRARY_PATH=/usr/local/lib/ollama

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /app

# Install Python dependencies first (layer caching)
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app/
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ollama model storage
ENV OLLAMA_MODELS=/home/appuser/.ollama/models
RUN mkdir -p /home/appuser/.ollama && chown -R appuser:appuser /home/appuser

# Runtime configuration defaults (overridden per deployment)
ENV OLLAMA_HOST=http://127.0.0.1:11434
ENV MODEL_NAME=llama3.2:1b
ENV MODEL_VERSION=1.0.0
ENV HARDWARE_TYPE=cpu
ENV ENVIRONMENT=production
ENV DEPLOYMENT_TARGET=unknown

EXPOSE 8000 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=600s --retries=5 \
    CMD curl -f http://localhost:8000/health || exit 1

USER appuser

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
