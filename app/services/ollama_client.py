"""
Ollama client service — abstracts communication with the Ollama inference runtime.

Why Ollama?
- Ollama packages LLMs in a portable format (GGUF) optimized for CPU and GPU.
- It auto-detects CUDA/ROCm and offloads layers to GPU when available.
- Same API works on laptop, cloud VM, and on-prem GPU cluster.
"""

import time
from dataclasses import dataclass

import httpx
import structlog

from app.config import Settings, HardwareType

logger = structlog.get_logger()


@dataclass
class InferenceResult:
  response_text: str
  latency_ms: float
  model: str
  hardware_type: str
  tokens_generated: int


class OllamaClient:
  def __init__(self, settings: Settings):
    self.settings = settings
    self.base_url = settings.ollama_host.rstrip("/")

  def _build_options(self) -> dict:
    """Build Ollama generation options based on detected hardware."""
    options: dict = {
      "num_predict": self.settings.max_tokens,
    }

    if self.settings.hardware_type == HardwareType.GPU:
      # num_gpu: number of model layers to offload to GPU
      # Higher = faster inference, more VRAM required
      options["num_gpu"] = self.settings.gpu_layers
    else:
      # CPU: control thread parallelism only.
      # Do not set num_batch too low — Ollama warmup requires a larger batch.
      options["num_thread"] = self.settings.cpu_threads

    return options

  async def health_check(self) -> dict:
    """Verify Ollama is running and the configured model is available."""
    async with httpx.AsyncClient(timeout=30) as client:
      response = await client.get(f"{self.base_url}/api/tags")
      response.raise_for_status()
      models = response.json().get("models", [])
      model_names = [m.get("name", "") for m in models]
      model_available = any(
        self.settings.model_name in name for name in model_names
      )
      return {
        "ollama_reachable": True,
        "model_available": model_available,
        "available_models": model_names,
        "configured_model": self.settings.model_name,
      }

  async def generate(self, prompt: str) -> InferenceResult:
    """Run inference against Ollama and measure latency."""
    payload = {
      "model": self.settings.model_name,
      "prompt": prompt,
      "stream": False,
      "options": self._build_options(),
    }

    start = time.perf_counter()
    async with httpx.AsyncClient(
      timeout=self.settings.request_timeout_seconds
    ) as client:
      response = await client.post(
        f"{self.base_url}/api/generate", json=payload
      )
      response.raise_for_status()
      data = response.json()

    latency_ms = (time.perf_counter() - start) * 1000

    return InferenceResult(
      response_text=data.get("response", ""),
      latency_ms=round(latency_ms, 2),
      model=self.settings.model_name,
      hardware_type=self.settings.hardware_type.value,
      tokens_generated=data.get("eval_count", 0),
    )

  async def pull_model(self) -> None:
    """Pull model if not present — used during container startup."""
    logger.info("pulling_model", model=self.settings.model_name)
    async with httpx.AsyncClient(timeout=600) as client:
      response = await client.post(
        f"{self.base_url}/api/pull",
        json={"name": self.settings.model_name, "stream": False},
      )
      response.raise_for_status()
    logger.info("model_pulled", model=self.settings.model_name)
