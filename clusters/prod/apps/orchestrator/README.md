# Unified Dagster Orchestrator

This directory contains Kubernetes manifests for the unified Dagster orchestrator that manages both trading and blog jobs.

## Architecture

```
orchestrator namespace
├── dagster-webserver (UI on port 3000)
├── dagster-daemon (scheduler & run coordinator)
├── dagster-logs-pvc (compute logs storage)
└── models-pvc (ML model artifacts)
          │
          ├──────────────────────────┐
          ▼                          ▼
    trading namespace           web namespace
    ├── TimescaleDB             ├── PostgreSQL (blog_db)
    │   (market data)           └── Ollama (Gemma 3 LLM)
```

## Jobs & Schedules

| Job | Description | Schedule |
|-----|-------------|----------|
| `market_data_job` | S&P 500 market data integrity | Daily at 6:00 AM UTC |
| `regime_model_training_job` | XGBoost regime classifier training | Sundays at 10:00 PM UTC |
| `blog_summarization_job` | AI comment summarization | Daily at 2:00 AM UTC |

## Prerequisites

1. **Docker Image**: Build and push the orchestrator image:
   ```bash
   cd /path/to/algo-trading-system
   docker build -f Dockerfile.orchestrator -t sudhan03/orchestrator:latest .
   docker push sudhan03/orchestrator:latest
   ```

2. **Docker Hub Credentials**: Create secret in orchestrator namespace:
   ```bash
   kubectl create secret docker-registry dockerhub-creds \
     --docker-server=docker.io \
     --docker-username=sudhan03 \
     --docker-password=<password> \
     -n orchestrator
   ```

3. **Update Secrets**: Edit `secret.yaml` with actual credentials before deploying.

## Deployment

```bash
# Apply all manifests
kubectl apply -k clusters/prod/apps/orchestrator/

# Verify pods
kubectl get pods -n orchestrator

# Check logs
kubectl logs -n orchestrator -l app=dagster -c dagster-webserver
kubectl logs -n orchestrator -l app=dagster -c dagster-daemon
```

## Access

The Dagster UI is available at: http://dagster.suddu.duckdns.org

## Cross-Namespace Access

This orchestrator connects to services in other namespaces:

- **Trading DB**: `timescaledb.trading.svc.cluster.local:5432`
- **Blog DB**: `postgres-service.web.svc.cluster.local:5432`
- **Ollama**: `ollama-service.web.svc.cluster.local:11434`

## Files

| File | Purpose |
|------|---------|
| `namespace.yaml` | Creates `orchestrator` namespace |
| `rbac.yaml` | ServiceAccount, Role, RoleBinding for K8sRunLauncher |
| `pvc.yaml` | Persistent storage for logs and models |
| `configmap-env.yaml` | Environment variables for database connections |
| `configmap-instance.yaml` | Dagster instance configuration (dagster.yaml) |
| `secret.yaml` | Sensitive credentials (update before deploy!) |
| `deployment.yaml` | Dagster webserver, daemon, service, ingress |
| `kustomization.yaml` | Kustomize configuration |
