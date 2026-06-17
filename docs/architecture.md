# Architecture

## System Overview

The Multi-Architecture LLM Deployment Pipeline deploys a containerized Large Language Model (LLM) inference service across heterogeneous infrastructure: AWS cloud VMs, Azure VMs, on-premises GPU servers, and managed AI endpoints. A single Docker image runs everywhere without modification.

## Architecture Diagram

```mermaid
graph TB
    subgraph "CI/CD Pipeline"
        GH[GitHub Actions]
        REG[Container Registry<br/>GHCR]
        GH --> REG
    end

    subgraph "Traffic Management"
        GLB[Global Load Balancer<br/>Route 53 / Traffic Manager]
        ALB_A[AWS ALB<br/>Region A - Active]
        ALB_B[AWS ALB<br/>Region B - Passive]
        ONPREM_LB[On-Prem HAProxy<br/>GPU Cluster]
    end

    subgraph "AWS Region A - us-east-1 [Active]"
        EC2_A1[EC2 t3.xlarge<br/>CPU Node 1]
        EC2_A2[EC2 t3.xlarge<br/>CPU Node 2]
        ALB_A --> EC2_A1
        ALB_A --> EC2_A2
    end

    subgraph "AWS Region B - eu-west-1 [Passive/Failover]"
        EC2_B1[EC2 t3.xlarge<br/>CPU Node 1]
        ALB_B --> EC2_B1
    end

    subgraph "On-Prem GPU Cluster"
        GPU1[GPU Server 1<br/>NVIDIA T4/A100]
        GPU2[GPU Server 2<br/>NVIDIA T4/A100]
        CPU1[CPU Server<br/>Overflow/Failover]
        ONPREM_LB --> GPU1
        ONPREM_LB --> GPU2
        ONPREM_LB -.-> CPU1
    end

    subgraph "Managed Endpoints"
        SM[AWS SageMaker]
        AML[Azure ML]
    end

    subgraph "Monitoring"
        PROM[Prometheus]
        GRAF[Grafana]
        PROM --> GRAF
    end

    REG --> EC2_A1
    REG --> EC2_A2
    REG --> EC2_B1
    REG --> GPU1
    REG --> GPU2
    REG --> SM
    REG --> AML

    GLB -->|Active-Active| ALB_A
    GLB -->|Failover| ALB_B
    GLB -->|GPU Workloads| ONPREM_LB

    EC2_A1 --> PROM
    EC2_A2 --> PROM
    GPU1 --> PROM
    GPU2 --> PROM
```

## Sequence Diagram — Inference Request

```mermaid
sequenceDiagram
    participant Client
    participant LB as Load Balancer
    participant API as FastAPI Container
    participant Ollama as Ollama Runtime
    participant GPU as GPU/CUDA

    Client->>LB: POST /infer {"prompt": "Hello"}
    LB->>API: Route to healthy node
    API->>API: Check hardware type
    API->>Ollama: POST /api/generate
    alt GPU Node
        Ollama->>GPU: Matrix ops via CUDA
        GPU-->>Ollama: Token predictions
    else CPU Node
        Ollama->>Ollama: CPU inference (threads)
    end
    Ollama-->>API: Generated text
    API->>API: Record Prometheus metrics
    API-->>Client: {"response": "...", "latency_ms": 150}
```

## Multi-Region Traffic Patterns

### Active-Active (AWS Region A)
- Both nodes in Region A receive traffic simultaneously
- ALB distributes requests with health-check-based routing
- Used for: production traffic, low-latency serving

### Active-Passive (AWS Region B)
- Region B runs but receives no traffic unless Region A fails
- Route 53 health checks trigger DNS failover
- Used for: disaster recovery, compliance (EU data residency)

### On-Prem GPU Cluster
- Primary inference for latency-sensitive or data-sovereign workloads
- HAProxy load-balances across GPU nodes
- CPU node serves as overflow when GPU capacity is saturated

## Component Responsibilities

| Component | Responsibility | Why It Exists |
|-----------|---------------|---------------|
| FastAPI | HTTP API, health checks, metrics | Standard REST interface for any client |
| Ollama | LLM runtime, model loading, inference | Portable model format, CPU/GPU auto-detect |
| Docker | Containerization | Same image everywhere, dependency isolation |
| Terraform | Infrastructure provisioning | Version-controlled, repeatable infra |
| Ansible | Host configuration | Idempotent setup of Docker, NVIDIA, CUDA |
| Prometheus | Metrics collection | Industry-standard monitoring |
| Grafana | Dashboards and alerting | Visualize deployment health |
| GitHub Actions | CI/CD orchestration | Automated build-test-deploy pipeline |
