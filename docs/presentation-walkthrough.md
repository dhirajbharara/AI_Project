# Interview / Assignment Presentation Walkthrough

A step-by-step guide to demonstrating this project in 20-30 minutes.

---

## Before the Presentation (15 min prep)

```bash
cd /home/dhirajbh/ai_project

# 1. Start local stack
make up

# 2. Wait for model download (~2 min first time)
curl -s http://localhost:8000/health

# 3. Run validation to confirm everything works
make validate

# 4. Open Grafana
# Browser: http://localhost:3000 (admin/admin)
```

Have these browser tabs ready:
- GitHub repo (file tree visible)
- Grafana dashboard
- Architecture diagram (`docs/architecture.md` rendered)
- GitHub Actions workflows page

---

## Presentation Structure (25 minutes)

### Part 1: Problem Statement (2 min)

> "I built an enterprise-grade pipeline for deploying Large Language Models across multiple infrastructure targets — cloud VMs, managed AI endpoints, and on-premises GPU servers — using a single container image."

Key points:
- LLMs are not just Python scripts; they need infrastructure, monitoring, and safe deployment practices
- Different environments (cloud, on-prem) have different requirements (GPU drivers, networking)
- Production requires: validation, rollback, audit trails, security scanning

### Part 2: Architecture Overview (5 min)

Open `docs/architecture.md` and walk through the Mermaid diagram.

**Say:**
1. "One Docker image runs everywhere — AWS Region A, Region B, on-prem GPU cluster"
2. "Traffic flows through load balancers with active-active in Region A, passive failover in Region B"
3. "On-prem GPU cluster handles latency-sensitive workloads with NVIDIA CUDA acceleration"
4. "Prometheus + Grafana provide centralized monitoring across all targets"

Point to the sequence diagram:
> "A client sends a prompt → Load Balancer → FastAPI → Ollama → GPU via CUDA → response with latency metrics"

### Part 3: Live Demo — Local Deployment (5 min)

```bash
# Show health check
curl http://localhost:8000/health | jq .

# Show readiness (model loaded)
curl http://localhost:8000/ready | jq .

# Run inference
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is Kubernetes?"}' | jq .

# Show hardware detection
./scripts/detect-hardware.sh

# Run full validation suite
./scripts/validate-deployment.sh http://localhost:8000
```

**Explain while running:**
- `/health` = liveness (is the process alive?)
- `/ready` = readiness (is the model loaded and able to serve?)
- `/infer` = actual LLM inference with latency tracking
- Validation sends 3 prompts and fails the pipeline if any check fails

### Part 4: CI/CD Pipeline (5 min)

Open `.github/workflows/ci.yml` in GitHub.

Walk through each stage:

| Stage | What to Say |
|-------|------------|
| Model Packaging | "We create a manifest describing the model — not bundling 1.3GB into the image" |
| Unit Tests | "FastAPI endpoints tested before any container build" |
| Security Scan | "Trivy scans for CVEs; Bandit checks Python code for security issues" |
| Docker Build | "Single Dockerfile, multi-stage — Ollama binary + FastAPI app" |
| Image Scan + Push | "Image scanned again after build, then pushed to GHCR with git SHA tag" |

Then show the three deploy workflows:
- `deploy-cloud-vm.yml` — Terraform → Ansible → Deploy → Validate
- `deploy-managed-endpoint.yml` — SageMaker / Azure ML
- `deploy-onprem-gpu.yml` — NVIDIA drivers, CUDA, GPU verification

### Part 5: Infrastructure as Code (4 min)

Open `terraform/modules/aws-ec2/main.tf`.

**Explain:**
- "Terraform creates VPC, subnets, security groups, EC2 instances, ALB, EBS storage"
- "Security groups are firewall rules — port 8000 for API, port 22 for Ansible SSH"
- "Same module used in Region A (active) and Region B (passive failover)"

Show `terraform/environments/` — three separate state files for multi-region.

Open `ansible/playbooks/site.yml`:

**Explain:**
- "Ansible configures what Terraform creates"
- "Auto-detects CPU vs GPU, installs Docker, NVIDIA drivers, CUDA"
- "Deploys the same container image with hardware-specific environment variables"

### Part 6: Monitoring (3 min)

Open Grafana at `http://localhost:3000`.

Show the LLM Pipeline dashboard:
- Deployment status (model available gauge)
- Inference latency p95
- CPU / Memory / GPU utilization
- Request rate and error rate

**Say:**
> "Prometheus scrapes /metrics from every node every 15 seconds. Alerts fire if model becomes unavailable or latency exceeds 30 seconds."

### Part 7: Rollback and Manifests (3 min)

```bash
# Show manifest structure
cat manifests/latest.json 2>/dev/null || ./scripts/generate-manifest.sh && cat manifests/latest.json | jq .

# Explain rollback
cat docs/rollback-flow.md  # or summarize verbally
```

**Say:**
- "Every deployment generates a JSON manifest with model version, git commit, hardware type"
- "If validation fails during rolling deploy, automatic rollback to previous manifest"
- "Manual rollback: `./scripts/rollback.sh <manifest-id>`"

### Part 8: Key Design Decisions (3 min)

Reference `docs/concepts.md` for deep explanations:

1. **Why containerization?** Same image everywhere, isolated dependencies
2. **Why Ollama?** Portable, auto-detects GPU, simple API
3. **Why CPU for cloud, GPU for on-prem?** Cost vs performance tradeoff
4. **Why CUDA?** GPU matrix math is 10-100x faster for LLM inference
5. **Why Terraform + Ansible?** Provision vs configure separation
6. **Why validation gates?** Never deploy a broken model to production

---

## Anticipated Questions and Answers

**Q: Why not use Kubernetes?**
> A: This PoC targets VM-based deployments common in enterprises. The same container image and Ansible roles would work in Kubernetes with minimal changes (Deployment manifests instead of docker_container Ansible module). I can extend this to EKS/AKS.

**Q: How do you handle model updates?**
> A: Change `MODEL_NAME` env var, rebuild image, rolling deploy. Manifest tracks every version. Rollback reverts to previous image tag.

**Q: What about secrets management?**
> A: GitHub Actions secrets for cloud credentials. Production would use AWS Secrets Manager or HashiCorp Vault. No secrets in the container image or Terraform state.

**Q: How does multi-region failover work?**
> A: Route 53 health checks on Region A ALB. If unhealthy, DNS fails over to Region B ALB. Region B runs in passive mode (warm standby).

**Q: How do you ensure the same image runs on GPU and CPU?**
> A: Environment variable `HARDWARE_TYPE` + auto-detection via `nvidia-smi`. Ollama handles GPU offloading internally. Ansible passes GPU-specific env vars only on GPU nodes.

**Q: What model would you use in production?**
> A: Depends on use case. `llama3.2:1b` for demo. Production might use `llama3.1:70b` on GPU cluster or a fine-tuned model. The pipeline is model-agnostic — change `MODEL_NAME`.

**Q: How do you handle scaling?**
> A: Cloud VMs: ALB + auto-scaling group (add to Terraform). Managed endpoints: SageMaker/Azure ML auto-scaling. On-prem: HAProxy + additional GPU nodes in inventory.

---

## Quick Demo Script (5 min version)

If time is limited, run this script:

```bash
#!/bin/bash
echo "=== 1. Health ===" && curl -s localhost:8000/health | jq .
echo "=== 2. Inference ===" && curl -s -X POST localhost:8000/infer -H 'Content-Type: application/json' -d '{"prompt":"Hello"}' | jq .
echo "=== 3. Hardware ===" && ./scripts/detect-hardware.sh
echo "=== 4. Validation ===" && ./scripts/validate-deployment.sh http://localhost:8000
echo "=== 5. Metrics ===" && curl -s localhost:8000/metrics | head -5
echo "=== 6. Manifest ===" && DEPLOYMENT_TARGET=demo ./scripts/generate-manifest.sh
echo "=== Done ==="
```

---

## Files to Highlight

| File | Why Show It |
|------|------------|
| `docker/Dockerfile` | Single image for all targets |
| `app/main.py` | FastAPI with health, infer, metrics |
| `.github/workflows/ci.yml` | Full CI/CD pipeline |
| `terraform/modules/aws-ec2/main.tf` | IaC with networking + security |
| `ansible/playbooks/site.yml` | Configuration management |
| `scripts/validate-deployment.sh` | Automated validation gate |
| `scripts/rollback.sh` | Automatic recovery |
| `monitoring/grafana/dashboards/llm-pipeline.json` | Observability |
| `docs/architecture.md` | System design |
| `manifests/latest.json` | Deployment audit trail |
