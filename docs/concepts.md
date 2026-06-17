# DevOps and AI Concepts Explained

This document explains every design decision, DevOps concept, and AI concept used in this project.

---

## AI Concepts

### What is a Large Language Model (LLM)?

An LLM is a neural network trained on vast text data to predict the next word (token) in a sequence. When you send a prompt like "What is AI?", the model generates a response token by token.

**In this project:** We use `llama3.2:1b` — a 1-billion parameter model from Meta, small enough for PoC demos but representative of production patterns.

### What is Inference?

Inference is running a trained model to generate outputs. Unlike training (which requires GPUs for weeks), inference can run on CPU for small models or GPU for larger ones.

**In this project:** The `/infer` endpoint accepts a prompt and returns generated text with latency metrics.

### What is Ollama?

Ollama is a tool that runs LLMs locally. It downloads models in GGUF format (optimized for CPU/GPU inference) and provides a simple HTTP API.

**Why Ollama over HuggingFace Transformers?**
- Simpler deployment (single binary, no Python ML stack in production)
- Auto-detects GPU and offloads layers via CUDA
- Same API on every platform
- HuggingFace models can be converted to GGUF and used with Ollama

### What is GGUF?

GGUF (GPT-Generated Unified Format) is a file format for storing quantized LLM weights. Quantization reduces model size and memory usage (e.g., 4-bit instead of 16-bit floats).

### What is Token Generation?

LLMs generate text one token at a time. A token is roughly 3/4 of a word. "Hello" = 1 token. Longer responses = more tokens = more latency.

**In this project:** We track `tokens_generated` and `latency_ms` per request in Prometheus metrics.

---

## CPU vs GPU Decisions

### When to Use CPU

| Scenario | Why CPU Works |
|----------|--------------|
| Small models (< 3B parameters) | Fits in RAM, acceptable latency |
| Low traffic / dev environments | Cost-effective ($0.10/hr vs $0.50+/hr for GPU) |
| Cloud VMs without GPU quota | Default AWS/Azure instances are CPU-only |
| Failover / overflow nodes | Handle traffic when GPU nodes are saturated |

**CPU optimizations in this project:**
- `num_thread`: parallel CPU threads for matrix operations
- `num_batch`: batch size for prompt processing
- Instance type: `t3.xlarge` (4 vCPU, 16GB RAM)

### When to Use GPU

| Scenario | Why GPU is Required |
|----------|-------------------|
| Large models (7B+ parameters) | Too slow on CPU (minutes per response) |
| Production latency SLAs (< 2s) | GPU is 10-100x faster for matrix math |
| High throughput (many concurrent users) | GPU parallelizes across thousands of cores |
| On-prem dedicated inference | Maximize hardware investment |

**GPU optimizations in this project:**
- `num_gpu`: number of model layers offloaded to GPU VRAM
- `gpu_memory_fraction`: limit VRAM usage to avoid OOM
- Instance type: `g4dn.xlarge` (NVIDIA T4, 16GB VRAM)

### How Auto-Detection Works

1. Container starts → runs `nvidia-smi`
2. If GPU found → set `HARDWARE_TYPE=gpu`, apply GPU options
3. If not found → set `HARDWARE_TYPE=cpu`, apply CPU thread options
4. Ansible also detects hardware before deploying the container

---

## Why CUDA is Needed

**CUDA** (Compute Unified Device Architecture) is NVIDIA's parallel computing platform.

**The problem:** LLM inference is essentially billions of matrix multiplications. CPUs have 4-64 cores. GPUs have 2,000-16,000 cores designed for exactly this math.

**Without CUDA:** The CPU runs inference using standard libraries (slow for large models).
**With CUDA:** Ollama sends matrix operations to the GPU via CUDA drivers, getting 10-100x speedup.

**The stack:**
```
FastAPI → Ollama → CUDA Driver → NVIDIA GPU Hardware
```

**CUDA installation** is handled by Ansible's `nvidia` role:
1. Install NVIDIA driver (kernel module for GPU communication)
2. Install NVIDIA Container Toolkit (lets Docker access the GPU)
3. Verify with `nvidia-smi` and Docker GPU test

---

## DevOps Concepts

### Why Containerization?

**Problem:** "Works on my machine" — different OS, Python versions, missing libraries across dev/staging/prod.

**Solution:** Docker packages the application + all dependencies into an immutable image.

**Benefits:**
- Same image on AWS, Azure, on-prem, laptop
- Isolated from host OS changes
- Versioned artifacts (image tags = git SHAs)
- Fast rollback (pull previous image tag)

### Why Terraform?

**Problem:** Clicking in AWS Console to create VMs is not repeatable, auditable, or version-controlled.

**Solution:** Terraform describes desired infrastructure in `.tf` files.

**Benefits:**
- `terraform plan` shows what will change before applying
- State file tracks what exists
- Modules reuse patterns (AWS module works for Region A and B)
- Destroy and recreate identically

**Terraform vs Ansible:**
- Terraform = creates infrastructure (VMs, networks, firewalls)
- Ansible = configures infrastructure (install Docker, deploy app)

### Why Ansible?

**Problem:** After Terraform creates a VM, it's a bare Ubuntu install. You need Docker, GPU drivers, and the app.

**Solution:** Ansible playbooks define the desired configuration state.

**Benefits:**
- Idempotent: run 10 times, same result
- Agentless: uses SSH, no daemon on targets
- Roles: reusable (nvidia role works on any GPU server)
- Tags: run only specific parts (`--tags deploy`)

### Why Prometheus?

**Problem:** You deployed an LLM but can't tell if it's healthy, fast, or running out of memory.

**Solution:** Prometheus scrapes metrics from `/metrics` endpoints every 15 seconds.

**What we monitor:**
- `llm_model_available` — is the model loaded?
- `llm_inference_latency_seconds` — how fast are responses?
- `llm_inference_requests_total` — request count and error rate
- Node exporter — CPU, memory, disk on each host
- DCGM exporter — GPU utilization, VRAM usage

### Why Grafana?

Prometheus stores numbers. Grafana turns them into dashboards and alerts humans can understand.

### Why GitHub Actions?

**Problem:** Manual deployments are error-prone and don't scale.

**Solution:** CI/CD pipeline automates build → test → scan → deploy → validate.

**Pipeline gates:**
- Unit tests must pass before Docker build
- Security scan must pass before registry push
- Validation must pass before manifest update
- Failed validation triggers automatic rollback

### Why Deployment Manifests?

Every deployment generates a JSON manifest recording:
- What was deployed (model version, container image)
- Where it was deployed (target, hardware type)
- When (timestamp, git commit)
- Validation results

**Purpose:** Audit trail, rollback reference, compliance evidence.

---

## Networking Concepts

### Security Groups / NSGs (Firewall Rules)

Control which traffic can reach your LLM servers:
- Port 8000: inference API (from allowed CIDRs)
- Port 22: SSH (from admin network only)
- Port 9100: Prometheus node exporter (from monitoring network)

### Load Balancers

Distribute traffic across multiple LLM nodes:
- **ALB (AWS):** HTTP health checks on `/ready`, routes to healthy nodes
- **HAProxy (on-prem):** round-robin across GPU cluster

### Active-Active vs Active-Passive

- **Active-Active:** Both regions serve traffic (higher availability, load distribution)
- **Active-Passive:** Standby region only receives traffic during failover (cost savings)
