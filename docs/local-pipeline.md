# Local Pipeline Guide (Laptop Deployment)

This guide explains how to run the **same deployment pipeline** on your laptop using `Makefile` and `scripts/` — without GitHub Actions, Terraform, or Ansible.

---

## Local vs Automated Pipeline

| Stage | GitHub Actions (production) | Your laptop (local) |
|-------|----------------------------|---------------------|
| Model packaging | `ci.yml` → `package-model` job | `make package` |
| Unit tests | `ci.yml` → `unit-test` job | `make test` |
| Security scan | `ci.yml` → Trivy | *(skip locally)* |
| Docker build | `ci.yml` → `docker-build` | `make build` or `make up` |
| Push registry | `ci.yml` → GHCR push | *(skip — image stays local)* |
| Terraform | `deploy-cloud-vm.yml` | *(skip — use Docker Compose)* |
| Ansible | deploy workflows | *(skip — compose handles it)* |
| Deploy | `rollout.sh` on VMs | `make up` |
| Validation | `validate-deployment.sh` | `make validate` |
| Manifest | `generate-manifest.sh` | `make manifest` |
| Rollback | `rollback.sh` | `make down` + previous image |

**Key idea:** The pipeline is defined in the repo. On a laptop you run a **subset** of stages manually. In production, GitHub Actions runs the full chain.

---

## One-Time Setup

```bash
cd ~/ai_project

# Ensure scripts are executable
chmod +x scripts/*.sh docker/entrypoint.sh
```

---

## Full Local Pipeline (Recommended Order)

Run these in order for a complete demo:

```bash
# Stage 1 — Model packaging
make package

# Stage 2 — Unit tests (optional but recommended)
make test

# Stage 3 — Build + deploy locally
make up

# Stage 4 — Wait until API is ready (important on first run)
make wait

# Stage 5 — Validate deployment (must pass)
make validate

# Stage 6 — Record deployment manifest
make manifest
```

---

## What Each Command Does

### `make up`
- Builds Docker image from `docker/Dockerfile`
- Starts `llm-api`, Prometheus, Grafana via Compose
- **First run only:** downloads `llama3.2:1b` (~1.3 GB) into `data/ollama/`
- **Later runs:** reuses cached model (no re-download)

### `make wait`
- Polls `http://localhost:8000/ready` until model is loaded
- Use this instead of guessing when download is done

### `make validate`
- Checks `/health`, `/ready`, runs 3 inference prompts
- Fails the pipeline if model cannot respond
- CPU mode allows up to 120s latency per prompt

### `make logs`
- Follows container logs: `docker compose logs -f llm-api`

### `make down`
- Stops containers **but keeps model cache** in `data/ollama/`

### `make clean`
- Stops containers only (same as `down`)

### `make clean-all`
- Stops containers **and deletes model cache** (forces 1.3 GB re-download)

---

## Model Cache — Why It Re-Downloads

The model is stored on your laptop at:

```
~/ai_project/data/ollama/
```

| Action | Model cache | Re-download? |
|--------|-------------|--------------|
| `make down` | Kept | No |
| `make up` (after down) | Kept | No |
| `docker compose build` | Kept | No |
| `make clean-all` | **Deleted** | **Yes** |
| `docker compose down -v` | **Deleted** | **Yes** |
| Deleting `data/ollama/` folder | **Deleted** | **Yes** |

If logs show `pulling manifest ... 153 MB/1.3 GB`, the model is still downloading. **Wait 5–10 minutes** on first run. Do not stop the container.

After download completes once, you should see:

```
Model llama3.2:1b already cached — skipping download.
```

---

## Verify Model Cache Exists

```bash
# Check cache folder on host
ls -lh data/ollama/models/blobs/ 2>/dev/null | head

# Check inside container
docker exec docker-llm-api-1 ollama list
```

Expected output includes `llama3.2:1b`.

---

## Quick Health Checks

```bash
curl -s http://localhost:8000/health
curl -s http://localhost:8000/ready
curl -s -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello"}'
```

---

## Monitoring (Optional)

| Service | URL |
|---------|-----|
| API | http://localhost:8000 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 (admin/admin) |

---

## Troubleshooting

### Logs show model downloading again

1. Check if cache exists: `ls data/ollama/models/blobs/`
2. If empty, this is first run — wait for completion
3. If you ran `make clean-all` or `docker compose down -v`, cache was wiped intentionally

### `make validate` fails on health

- API not started yet → run `make wait`
- Container not running → `docker compose -f docker/docker-compose.yml ps`

### `make validate` fails on inference

- Model still downloading → `make logs` and wait for `Uvicorn running`
- Check runtime: `docker exec docker-llm-api-1 ls /usr/local/lib/ollama/llama-server`

### Inference is slow (20–40s per prompt)

- Normal on CPU for `llama3.2:1b`
- First prompt after startup is slower (model loading into RAM)

---

## Interview Explanation (30 seconds)

> "I implemented a 13-stage enterprise deployment pipeline. On my laptop I execute the core stages locally: package the model, build the Docker image, deploy with Compose, validate inference with automated prompts, and generate a JSON deployment manifest. The same scripts and Dockerfile are used in GitHub Actions for cloud VM, managed endpoint, and on-prem GPU deployments with Terraform and Ansible."

---

## File Map (Local Pipeline)

| File | Role |
|------|------|
| `Makefile` | Local pipeline entry points |
| `docker/docker-compose.yml` | Local deploy target |
| `docker/Dockerfile` | Container image |
| `docker/entrypoint.sh` | Start Ollama + FastAPI |
| `scripts/validate-deployment.sh` | Post-deploy validation gate |
| `scripts/generate-manifest.sh` | Deployment audit JSON |
| `scripts/wait-for-ready.sh` | Wait for model readiness |
| `data/ollama/` | Persistent model cache (local) |
