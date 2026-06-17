# File Reference

Every file in this repository, why it exists, how it works, and where it is used.

---

## Application (`app/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `app/main.py` | HTTP API entry point for inference | FastAPI app with `/health`, `/ready`, `/infer`, `/metrics` endpoints. Auto-detects GPU at startup. | Container runtime, all deployment targets |
| `app/config.py` | Centralized configuration | Pydantic settings loaded from env vars. CPU/GPU settings separated. | Imported by all app modules |
| `app/requirements.txt` | Python dependencies | Pinned versions for reproducible builds | Docker build, CI unit tests |
| `app/services/ollama_client.py` | Ollama API abstraction | Async HTTP client for model health, inference, pull. Applies CPU/GPU options. | Called by `/infer` and `/ready` endpoints |
| `app/services/metrics.py` | Prometheus metric definitions | Counter, Histogram, Gauge metrics for inference monitoring | Exposed at `/metrics` endpoint |

---

## Container (`docker/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `docker/Dockerfile` | Single production image | Multi-stage build: Ollama binary + Python app. Non-root user. Health check. | CI build, all deployments |
| `docker/entrypoint.sh` | Container startup orchestration | Starts Ollama, pulls model, detects GPU, starts FastAPI | Container CMD |
| `docker/docker-compose.yml` | Local dev stack | API + Prometheus + Grafana for local testing | `make up`, presentation demo |

---

## Tests (`tests/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `tests/test_api.py` | Unit tests for API endpoints | pytest with mocked Ollama client | CI `unit-test` job |
| `tests/conftest.py` | pytest configuration | asyncio backend fixture | All tests |
| `pytest.ini` | pytest settings | Sets test paths and asyncio mode | CI and local `make test` |

---

## Terraform (`terraform/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `modules/aws-ec2/main.tf` | AWS infrastructure module | VPC, subnets, security groups, EC2, ALB, EBS | Region A, Region B deployments |
| `modules/aws-ec2/variables.tf` | Module input parameters | Instance types, CIDR blocks, GPU toggle | Module consumers |
| `modules/aws-ec2/outputs.tf` | Module outputs | API endpoint, instance IPs | CI/CD, Ansible inventory |
| `modules/aws-ec2/templates/user_data.sh.tpl` | EC2 bootstrap script | Initial packages, instance tagging | EC2 user_data on launch |
| `modules/azure-vm/main.tf` | Azure infrastructure module | VNet, NSG, VM, managed disk, LB | Azure deployments |
| `modules/azure-vm/variables.tf` | Azure module inputs | VM sizes, SSH key, GPU toggle | Azure environment |
| `modules/azure-vm/outputs.tf` | Azure module outputs | Public IP, API endpoint | CI/CD |
| `modules/onprem-vm/main.tf` | On-prem node registration | SSH provisioning, firewall rules JSON | On-prem GPU cluster |
| `modules/onprem-vm/variables.tf` | On-prem inputs | GPU/CPU hostnames, IPs, SSH config | On-prem environment |
| `environments/aws-region-a/main.tf` | Region A deployment | Active-active, 2 CPU instances | `deploy-cloud-vm.yml` |
| `environments/aws-region-b/main.tf` | Region B deployment | Passive failover, 1 CPU instance | `deploy-cloud-vm.yml` |
| `environments/azure/main.tf` | Azure deployment | Single VM with LB | `deploy-cloud-vm.yml` |
| `environments/onprem/main.tf` | On-prem deployment | 2 GPU + 1 CPU nodes | `deploy-onprem-gpu.yml` |

---

## Ansible (`ansible/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `ansible.cfg` | Ansible settings | Inventory path, privilege escalation, Python interpreter | All playbook runs |
| `inventory/aws.yml` | AWS host inventory | Static hosts with hardware_type, region vars | Cloud VM deployments |
| `inventory/onprem.yml` | On-prem host inventory | GPU and CPU node groups | On-prem deployments |
| `playbooks/site.yml` | Master playbook | Orchestrates all roles with hardware detection | All deploy workflows |
| `roles/common/tasks/main.yml` | Base host setup | Packages, config directory, model cache | All hosts |
| `roles/common/tasks/detect_hardware.yml` | Hardware auto-detection | Runs nvidia-smi, sets hardware_type fact | Playbook pre_tasks |
| `roles/common/templates/config.env.j2` | Deployment config template | CPU/GPU-specific env vars | Written to /etc/llm-pipeline/ |
| `roles/docker/tasks/main.yml` | Docker installation | Docker CE, compose plugin, Python SDK | All hosts before app deploy |
| `roles/nvidia/tasks/main.yml` | NVIDIA driver + CUDA | Driver install, container toolkit, Docker GPU config | GPU nodes only |
| `roles/nvidia/tasks/verify_gpu.yml` | GPU verification | nvidia-smi, Docker GPU test | Post-deploy on GPU nodes |
| `roles/llm_runtime/tasks/main.yml` | Container deployment | Pull image, start with CPU or GPU config | All hosts, `--tags deploy` |
| `roles/monitoring/tasks/main.yml` | Monitoring agents | node_exporter, DCGM exporter | All hosts |

---

## Scripts (`scripts/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `package-model.sh` | Model packaging stage | Creates model-manifest.json | CI `package-model` job |
| `validate-deployment.sh` | Post-deploy validation | Health, readiness, 3 inference prompts, latency check | All deploy workflows, fails pipeline on error |
| `generate-manifest.sh` | Deployment manifest creation | JSON with version, commit, hardware, timestamp | Post-validation in deploy workflows |
| `rollback.sh` | Deployment rollback | Reads manifest, re-deploys previous image via Ansible | Auto-triggered on failure, manual use |
| `rollout.sh` | Rolling deployment | Deploy + validate one node at a time | Deploy workflows |
| `detect-hardware.sh` | Hardware detection utility | Checks nvidia-smi, outputs cpu/gpu | CI, local testing, Ansible pre-task reference |

---

## Monitoring (`monitoring/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `prometheus/prometheus.yml` | Scrape configuration | Targets for API, node-exporter, DCGM | Prometheus container, production monitoring |
| `prometheus/alerts.yml` | Alerting rules | Model unavailable, high latency, errors | Prometheus alertmanager |
| `grafana/provisioning/datasources/prometheus.yml` | Grafana data source | Auto-configures Prometheus connection | Grafana startup |
| `grafana/provisioning/dashboards/dashboards.yml` | Dashboard provisioning | Loads dashboards from file path | Grafana startup |
| `grafana/dashboards/llm-pipeline.json` | Main dashboard | Deployment status, latency, CPU, GPU, tokens | Grafana UI |

---

## CI/CD (`.github/workflows/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `ci.yml` | Continuous integration | Package → Test → Scan → Build → Push | Every push/PR to main |
| `deploy-cloud-vm.yml` | Cloud VM deployment | Terraform → Ansible → Deploy → Validate → Manifest | Manual dispatch |
| `deploy-managed-endpoint.yml` | Managed AI deployment | SageMaker / Azure ML endpoint creation | Manual dispatch |
| `deploy-onprem-gpu.yml` | On-prem GPU deployment | Terraform → Ansible (NVIDIA) → Deploy → Validate | Manual dispatch |

---

## Documentation (`docs/`)

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `architecture.md` | System design | Mermaid diagrams, component table | Design reviews, presentation |
| `deployment-flow.md` | Pipeline stages | Flowchart, stage-by-stage explanation | Understanding the pipeline |
| `rollback-flow.md` | Rollback procedures | Flowchart, commands, safety mechanisms | Incident response |
| `concepts.md` | DevOps and AI education | CPU vs GPU, CUDA, Terraform, Ansible, Prometheus | Learning, interview prep |
| `presentation-walkthrough.md` | Demo guide | Step-by-step presentation script | Interview/assignment demo |
| `file-reference.md` | This file | Complete file inventory | Onboarding, code review |

---

## Root Files

| File | Why | How | Where Used |
|------|-----|-----|------------|
| `README.md` | Project overview | Quick start, architecture summary, requirements mapping | First point of entry |
| `Makefile` | Developer shortcuts | build, test, up, validate, detect targets | Local development |
| `.gitignore` | Exclude artifacts | Python cache, Terraform state, secrets | Git |
| `manifests/` | Deployment history | Auto-generated JSON manifests per deployment | Rollback, audit |
