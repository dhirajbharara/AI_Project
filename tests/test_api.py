"""
Unit tests for the FastAPI inference API.

These run in CI before Docker build to catch regressions early.
Integration tests against a live Ollama instance run in the validation stage.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock
from httpx import ASGITransport, AsyncClient

from app.config import Settings, HardwareType
from app.main import app
from app.services.ollama_client import InferenceResult, OllamaClient


@pytest.fixture
def mock_settings():
  return Settings(
    hardware_type=HardwareType.CPU,
    deployment_target="test",
    environment="test",
  )


@pytest.fixture
def mock_ollama_client():
  mock_client = MagicMock(spec=OllamaClient)
  mock_client.health_check = AsyncMock(return_value={
    "ollama_reachable": True,
    "model_available": True,
    "available_models": ["llama3.2:1b"],
    "configured_model": "llama3.2:1b",
  })
  mock_client.generate = AsyncMock(return_value=InferenceResult(
    response_text="Hello! How can I help you?",
    latency_ms=150.0,
    model="llama3.2:1b",
    hardware_type="cpu",
    tokens_generated=12,
  ))
  return mock_client


@pytest.fixture
async def client(mock_settings, mock_ollama_client):
  app.state.settings = mock_settings
  app.state.client = mock_ollama_client
  transport = ASGITransport(app=app)
  async with AsyncClient(transport=transport, base_url="http://test") as ac:
    yield ac


@pytest.mark.asyncio
async def test_health_endpoint(client):
  response = await client.get("/health")
  assert response.status_code == 200
  assert response.json()["status"] == "healthy"


@pytest.mark.asyncio
async def test_infer_endpoint_success(client, mock_ollama_client):
  response = await client.post("/infer", json={"prompt": "Hello"})
  assert response.status_code == 200
  data = response.json()
  assert data["response"] == "Hello! How can I help you?"
  assert data["latency_ms"] == 150.0
  mock_ollama_client.generate.assert_called_once()


@pytest.mark.asyncio
async def test_infer_empty_prompt_rejected(client):
  response = await client.post("/infer", json={"prompt": ""})
  assert response.status_code == 422


@pytest.mark.asyncio
async def test_metrics_endpoint(client):
  response = await client.get("/metrics")
  assert response.status_code == 200
  assert "llm_inference_requests_total" in response.text
