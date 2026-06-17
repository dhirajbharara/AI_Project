# Multi-Architecture LLM Deployment Pipeline

Enterprise-grade Proof of Concept for deploying Large Language Models across heterogeneous infrastructure — cloud VMs, managed AI endpoints, and on-premises GPU servers — using a single container image.

## Quick Start

```bash
# Build and start local stack (API + Prometheus + Grafana)
make up

# Wait for model download (~2 min), then validate
make validate

# Run inference
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is AI?"}' | jq .

# Open monitoring
# Grafana:  http://localhost:3000  (admin/admin)
# Prometheus: http://localhost:9090
```

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         GitHub Actions          │
                    │   Build → Test → Scan → Push    │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │     Container Registry (GHCR)    │
                    │   Same image for all targets     │
                    └──────────────┬──────────────────┘
           ┌───────────────────────┼───────────────────────┐
           │                       │                       │
    ┌──────▼──────┐        ┌──────▼──────┐        ┌──────▼──────┐
    │ AWS Region A │        │ AWS Region B │        │ On-Prem GPU │
    │  (Active)    │        │ (Passive)    │        │  Cluster    │
    │  CPU VMs     │        │  CPU VM      │        │  NVIDIA GPU │
    └──────┬──────┘        └──────┬──────┘        └──────┬──────┘
           │                       │                       │
           └───────────────────────┼───────────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   Prometheus + Grafana           │
                    │   Latency · CPU · GPU · Health   │
                    └─────────────────────────────────┘
```

See [docs/architecture.md](docs/architecture.md) for detailed diagrams.

## Requirements Mapping

| # | Requirement | Implementation |
|---|------------|----------------|
| 1 | Standardized deployment pipeline | 13 stages in [deployment-flow.md](docs/deployment-flow.md) |
| 2 | Cloud VM, Managed AI, On-prem GPU | 3 GitHub Actions workflows |
| 3 | Docker + FastAPI + Ollama | [docker/Dockerfile](docker/Dockerfile), [app/main.py](app/main.py) |
| 4 | Terraform (AWS, Azure, On-prem) | [terraform/modules/](terraform/modules/) |
| 5 | Ansible (Docker, NVIDIA, CUDA) | [ansible/roles/](ansible/roles/) |
| 6 | CPU/GPU auto-detection | [app/main.py](app/main.py), [ansible roles](ansible/roles/common/tasks/detect_hardware.yml) |
| 7 | Deployment validation | [scripts/validate-deployment.sh](scripts/validate-deployment.sh) |
| 8 | JSON deployment manifests | [scripts/generate-manifest.sh](scripts/generate-manifest.sh) |
| 9 | Multi-region hybrid architecture | Region A (active), Region B (passive), on-prem GPU |
| 10 | Prometheus + Grafana monitoring | [monitoring/](monitoring/) |

## Project Structure

```
├── app/                    # FastAPI inference API
├── docker/                 # Dockerfile, entrypoint, compose
├── terraform/              # IaC modules (AWS, Azure, on-prem)
├── ansible/                # Configuration management playbooks
├── scripts/                # Validation, rollout, rollback, manifests
├── monitoring/             # Prometheus + Grafana configs
├── .github/workflows/      # CI/CD pipeline definitions
├── tests/                  # Unit tests
├── docs/                   # Architecture, concepts, walkthrough
└── manifests/              # Auto-generated deployment manifests
```

## Pipeline Stages

1. **Model Packaging** — create model manifest
2. **Container Build** — Docker image with FastAPI + Ollama
3. **Image Scanning** — Trivy CVE scan
4. **Testing** — pytest unit tests
5. **Push Registry** — GHCR with git SHA tag
6. **Terraform Apply** — provision infrastructure
7. **Ansible Configure** — install Docker, NVIDIA, deploy container
8. **Deploy** — rolling deployment node by node
9. **Validation** — automated inference prompts (pipeline fails if validation fails)
10. **Rollout** — complete or rollback on failure
11. **Update Manifest** — JSON audit trail
12. **Notify** — deployment status notification

## Deployment Targets

### Cloud VM (`deploy-cloud-vm.yml`)
```bash
# Via GitHub Actions UI: Actions → Deploy — Cloud VM → Run workflow
# Select: aws-region-a | aws-region-b | azure
# Select: cpu | gpu
```

### Managed AI Endpoint (`deploy-managed-endpoint.yml`)
```bash
# Deploys to AWS SageMaker or Azure ML
# Same container image, managed scaling
```

### On-Prem GPU (`deploy-onprem-gpu.yml`)
```bash
# Configures NVIDIA drivers, CUDA, GPU verification
# Deploys to on-prem GPU cluster via Ansible
```

## Key Commands

```bash
make build          # Build Docker image
make test           # Run unit tests
make up             # Start local stack
make validate       # Run deployment validation
make detect         # Detect CPU vs GPU
make package        # Package model manifest

./scripts/rollout.sh ansible/inventory/aws.yml     # Rolling deploy
./scripts/rollback.sh <manifest-id>                 # Rollback
./scripts/validate-deployment.sh http://host:8000   # Validate
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design, Mermaid diagrams |
| [Deployment Flow](docs/deployment-flow.md) | Pipeline stages explained |
| [Rollback Flow](docs/rollback-flow.md) | Rollback procedures |
| [Concepts](docs/concepts.md) | DevOps and AI concepts for beginners |
| [Local Pipeline](docs/local-pipeline.md) | Laptop deployment guide (your scenario) |
| [Presentation Walkthrough](docs/presentation-walkthrough.md) | Interview demo guide |
| [File Reference](docs/file-reference.md) | Every file explained |

## Technology Choices

| Technology | Purpose | Why |
|-----------|---------|-----|
| **Docker** | Containerization | Same image on all targets |
| **FastAPI** | HTTP API | Async, auto-docs, production-ready |
| **Ollama** | LLM runtime | Portable, CPU/GPU auto-detect |
| **Terraform** | Infrastructure | Version-controlled, repeatable |
| **Ansible** | Configuration | Idempotent host setup |
| **Prometheus** | Metrics | Industry-standard monitoring |
| **Grafana** | Dashboards | Visualize health and performance |
| **GitHub Actions** | CI/CD | Automated pipeline orchestration |

## License

MIT — Proof of Concept for educational and demonstration purposes.
