"""
Prometheus metrics for LLM inference monitoring.

Why Prometheus?
- Industry-standard pull-based metrics collection.
- Integrates with Grafana for dashboards and alerting.
- Tracks inference latency, request counts, and model health.
"""

from prometheus_client import Counter, Gauge, Histogram, Info

# Deployment metadata exposed as info metric
deployment_info = Info(
  "llm_deployment",
  "Deployment metadata including model version and target",
)

# Request tracking
inference_requests_total = Counter(
  "llm_inference_requests_total",
  "Total number of inference requests",
  ["model", "hardware_type", "status"],
)

inference_latency_seconds = Histogram(
  "llm_inference_latency_seconds",
  "Inference request latency in seconds",
  ["model", "hardware_type"],
  buckets=[0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0],
)

tokens_generated_total = Counter(
  "llm_tokens_generated_total",
  "Total tokens generated",
  ["model", "hardware_type"],
)

# Health gauges
model_available = Gauge(
  "llm_model_available",
  "Whether the configured model is loaded and available (1=yes, 0=no)",
)

ollama_reachable = Gauge(
  "llm_ollama_reachable",
  "Whether Ollama runtime is reachable (1=yes, 0=no)",
)
