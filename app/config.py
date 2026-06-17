"""
Application configuration loaded from environment variables.

Why environment variables?
- The same container image runs on CPU VMs, GPU servers, and managed endpoints.
- Hardware-specific settings (GPU layers, thread count) are injected at deploy time,
  not baked into the image. This is the "build once, deploy anywhere" principle.
"""

from enum import Enum
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class HardwareType(str, Enum):
  CPU = "cpu"
  GPU = "gpu"


class Settings(BaseSettings):
  model_config = SettingsConfigDict(
    env_file=".env",
    extra="ignore",
    protected_namespaces=(),
  )

  # Service identity
  app_name: str = "multi-arch-llm-pipeline"
  environment: str = "development"
  deployment_target: str = "local"

  # Ollama connection — Ollama runs as a sidecar or host process
  ollama_host: str = "http://localhost:11434"
  model_name: str = "llama3.2:1b"
  model_version: str = "1.0.0"

  # Hardware detection — set by Ansible/Terraform or auto-detected at startup
  hardware_type: HardwareType = HardwareType.CPU

  # CPU optimizations
  cpu_threads: int = 4

  # GPU optimizations (used when hardware_type=gpu)
  gpu_layers: int = 35

  # Inference limits
  max_tokens: int = 512
  request_timeout_seconds: int = 120

  # Monitoring
  metrics_enabled: bool = True


@lru_cache
def get_settings() -> Settings:
  return Settings()
