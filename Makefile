.PHONY: help build test up down wait validate package manifest detect logs clean clean-all pipeline-local

help:
	@echo "Multi-Architecture LLM Pipeline — Local Commands"
	@echo ""
	@echo "  make pipeline-local  Run full local pipeline (package→up→wait→validate→manifest)"
	@echo "  make up              Build + start stack (keeps model cache)"
	@echo "  make wait            Wait until model is ready"
	@echo "  make validate        Run deployment validation"
	@echo "  make manifest        Generate deployment manifest JSON"
	@echo "  make logs            Follow llm-api logs"
	@echo "  make down            Stop containers (keeps model cache)"
	@echo "  make clean           Same as down"
	@echo "  make clean-all       Stop + DELETE model cache (re-downloads 1.3GB)"
	@echo "  make build           Build Docker image only"
	@echo "  make test            Run unit tests"
	@echo "  make package         Package model manifest"
	@echo "  make detect          Detect CPU/GPU"

pipeline-local: package up wait validate manifest
	@echo "=== Local pipeline complete ==="

build:
	docker build -f docker/Dockerfile -t multi-arch-llm-pipeline:local .

test:
	pip install -r app/requirements.txt
	pytest tests/ -v

up:
	docker compose -f docker/docker-compose.yml up --build -d

down:
	docker compose -f docker/docker-compose.yml down

wait:
	chmod +x scripts/wait-for-ready.sh
	./scripts/wait-for-ready.sh http://localhost:8000

validate:
	chmod +x scripts/validate-deployment.sh
	MAX_LATENCY_MS=120000 ./scripts/validate-deployment.sh http://localhost:8000

manifest:
	chmod +x scripts/generate-manifest.sh
	DEPLOYMENT_TARGET=local HARDWARE_TYPE=cpu ENVIRONMENT=development \
		API_ENDPOINT=http://localhost:8000 ./scripts/generate-manifest.sh

package:
	chmod +x scripts/package-model.sh
	./scripts/package-model.sh

detect:
	chmod +x scripts/detect-hardware.sh
	./scripts/detect-hardware.sh

logs:
	docker compose -f docker/docker-compose.yml logs -f llm-api

clean: down

clean-all:
	docker compose -f docker/docker-compose.yml down
	rm -rf data/ollama
	@echo "Model cache deleted. Next 'make up' will re-download ~1.3GB."
