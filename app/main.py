"""
Multi-Architecture LLM Inference API

FastAPI application that provides:
- /health  — liveness and readiness probes for orchestrators
- /ready   — deep readiness check including model availability
- /infer   — synchronous text generation endpoint
- /metrics — Prometheus metrics exposition

This is the single entry point used across all deployment targets.
The same container image runs on AWS, Azure, on-prem, CPU, and GPU.
"""

import subprocess
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, HTTPException
from fastapi.responses import PlainTextResponse
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from pydantic import BaseModel, Field

from app.config import Settings, HardwareType, get_settings
from app.services.metrics import (
  deployment_info,
  inference_latency_seconds,
  inference_requests_total,
  model_available,
  ollama_reachable,
  tokens_generated_total,
)
from app.services.ollama_client import OllamaClient

structlog.configure(
  processors=[
    structlog.processors.TimeStamper(fmt="iso"),
    structlog.processors.JSONRenderer(),
  ]
)
logger = structlog.get_logger()


def detect_hardware() -> HardwareType:
  """
  Auto-detect GPU availability at startup.

  Why auto-detect?
  - Same image deploys to CPU and GPU nodes without modification.
  - nvidia-smi confirms CUDA driver + GPU hardware are present.
  - Falls back to CPU config if no GPU detected.
  """
  try:
    result = subprocess.run(
      ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
      capture_output=True,
      text=True,
      timeout=5,
    )
    if result.returncode == 0 and result.stdout.strip():
      logger.info("gpu_detected", gpu=result.stdout.strip())
      return HardwareType.GPU
  except (FileNotFoundError, subprocess.TimeoutExpired):
    pass
  logger.info("cpu_mode_detected")
  return HardwareType.CPU


@asynccontextmanager
async def lifespan(app: FastAPI):
  settings = get_settings()

  # Auto-detect hardware if not explicitly set via env var
  if settings.hardware_type == HardwareType.CPU:
    detected = detect_hardware()
    if detected == HardwareType.GPU:
      settings.hardware_type = HardwareType.GPU

  client = OllamaClient(settings)

  # Ensure model is available
  try:
    health = await client.health_check()
    if not health["model_available"]:
      await client.pull_model()
  except Exception as exc:
    logger.warning("startup_model_check_failed", error=str(exc))

  # Register deployment metadata for Prometheus
  deployment_info.info({
    "model_version": settings.model_version,
    "model_name": settings.model_name,
    "deployment_target": settings.deployment_target,
    "environment": settings.environment,
    "hardware_type": settings.hardware_type.value,
  })

  app.state.settings = settings
  app.state.client = client
  yield


app = FastAPI(
  title="Multi-Architecture LLM Pipeline",
  description="Enterprise LLM inference API — same image, any target",
  version="1.0.0",
  lifespan=lifespan,
)


class InferRequest(BaseModel):
  prompt: str = Field(..., min_length=1, max_length=4096)
  max_tokens: int | None = Field(default=None, ge=1, le=2048)


class InferResponse(BaseModel):
  response: str
  latency_ms: float
  model: str
  hardware_type: str
  tokens_generated: int


@app.get("/health")
async def health():
  """Liveness probe — returns 200 if the process is running."""
  return {"status": "healthy"}


@app.get("/ready")
async def ready():
  """
  Readiness probe — confirms Ollama is reachable and model is loaded.
  Kubernetes/orchestrators use this before routing traffic.
  """
  client: OllamaClient = app.state.client
  try:
    health = await client.health_check()
    ollama_reachable.set(1 if health["ollama_reachable"] else 0)
    model_available.set(1 if health["model_available"] else 0)
    if not health["ollama_reachable"]:
      raise HTTPException(status_code=503, detail="Ollama not reachable")
    if not health["model_available"]:
      raise HTTPException(status_code=503, detail="Model not available")
    return {"status": "ready", **health}
  except HTTPException:
    raise
  except Exception as exc:
    ollama_reachable.set(0)
    model_available.set(0)
    raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.post("/infer", response_model=InferResponse)
async def infer(request: InferRequest):
  """Run synchronous LLM inference on the given prompt."""
  client: OllamaClient = app.state.client
  settings: Settings = app.state.settings

  try:
    result = await client.generate(request.prompt)
    inference_requests_total.labels(
      model=result.model,
      hardware_type=result.hardware_type,
      status="success",
    ).inc()
    inference_latency_seconds.labels(
      model=result.model,
      hardware_type=result.hardware_type,
    ).observe(result.latency_ms / 1000)
    tokens_generated_total.labels(
      model=result.model,
      hardware_type=result.hardware_type,
    ).inc(result.tokens_generated)

    return InferResponse(
      response=result.response_text,
      latency_ms=result.latency_ms,
      model=result.model,
      hardware_type=result.hardware_type,
      tokens_generated=result.tokens_generated,
    )
  except Exception as exc:
    inference_requests_total.labels(
      model=settings.model_name,
      hardware_type=settings.hardware_type.value,
      status="error",
    ).inc()
    logger.error("inference_failed", error=str(exc))
    raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/metrics")
async def metrics():
  """Prometheus metrics endpoint."""
  return PlainTextResponse(
    generate_latest().decode("utf-8"),
    media_type=CONTENT_TYPE_LATEST,
  )
