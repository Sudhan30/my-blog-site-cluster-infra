# K3s Cluster Infrastructure

GitOps-managed K3s single-node cluster running trading system, blog, Dagster orchestrator, and monitoring stack.
Deployed via FluxCD with Kustomize overlays. Server: suddu-server (AMD Ryzen 9 7940HS, 64GB DDR5, Ubuntu 24.04).

## Stack
- K3s (single-node), FluxCD (GitOps), Traefik (ingress), cert-manager (TLS)
- Kustomize for manifest composition
- Docker Hub: `sudhan03/algo-trading`, `sudhan03/orchestrator`
- Domains: trading.sudharsana.dev, dagster.sudharsana.dev, grafana.sudharsana.dev

## Structure
```
clusters/prod/apps/
  trading/        Trading system (strategy engine, data ingestion, order executor, ML, research, etc.)
  orchestrator/   Dagster orchestration (pipelines, scheduling)
  monitoring/     Prometheus + Grafana + Loki + Promtail + blackbox-exporter
  backend/        Backend API services
  blog/           Blog application
  cert-manager/   Let's Encrypt TLS certificate automation
  infra/          Shared infrastructure (namespaces, network policies)
```

## Key Namespaces
- `trading` — all trading workloads (TimescaleDB, Redis, strategy engine, order executor, ML)
- `orchestrator` — Dagster instance + daemon
- `monitoring` — Prometheus, Grafana, Loki, exporters
- `default` — blog, backend services

## Infrastructure Details
- **TimescaleDB**: pg15, 10Gi PVC, db-init-configmap for schema bootstrap
- **Redis**: 7-alpine, 5Gi PVC, used for cache/state
- **Prometheus + Grafana + Loki**: full observability stack with alerting
- **Secrets**: `trading-secrets`, `orchestrator-secrets`, `docker-hub-creds` (K8s secrets, NOT in git)

## Commands

### Cluster Status
```bash
# Pod status by namespace
kubectl get pods -n trading
kubectl get pods -n orchestrator
kubectl get pods -n monitoring

# Resource usage
kubectl top pods -n trading
kubectl top nodes

# Logs
kubectl logs -n trading deployment/strategy-engine --tail=100
kubectl logs -n trading deployment/order-executor --tail=100 -f

# Describe for debugging
kubectl describe pod -n trading <pod-name>
```

### Deployment
```bash
# Apply changes via Kustomize
kubectl apply -k clusters/prod/apps/trading/
kubectl apply -k clusters/prod/apps/orchestrator/
kubectl apply -k clusters/prod/apps/monitoring/

# Restart a deployment
kubectl rollout restart deployment/<name> -n trading

# Watch rollout
kubectl rollout status deployment/<name> -n trading

# Dry-run before applying
kubectl apply -k clusters/prod/apps/trading/ --dry-run=client
```

### Docker Build & Push
```bash
# Trading system (from algo-trading-system repo)
sudo docker build -f Dockerfile.backtester -t sudhan03/algo-trading:<tag> .
sudo docker push sudhan03/algo-trading:<tag>

# Orchestrator
sudo docker build -t sudhan03/orchestrator:<tag> .
sudo docker push sudhan03/orchestrator:<tag>
```

### FluxCD
```bash
# Check reconciliation status
flux get all
flux reconcile source git flux-system
flux reconcile kustomization flux-system

# Suspend/resume reconciliation
flux suspend kustomization flux-system
flux resume kustomization flux-system
```

## Verification (run after EVERY manifest change)
1. `kubectl apply -k <path> --dry-run=client` to validate syntax
2. `kubectl diff -k <path>` to preview changes
3. Apply and monitor: `kubectl get pods -n <namespace> -w`
4. Verify health: `kubectl get pods -n <namespace>` shows all Running/Completed

## CRITICAL RULES
- NEVER modify production secrets directly in manifests; use `kubectl create secret` or sealed-secrets
- NEVER delete PVCs (persistent data loss is unrecoverable)
- NEVER apply manifests without `--dry-run=client` validation first
- Always use Kustomize for resource composition; no raw `kubectl apply -f` on individual files
- Test manifest changes locally before pushing to trigger FluxCD
- All image tags must be commit SHAs, not `:latest` (except orchestrator during dev)
- Resource requests AND limits required on every container

## Conventions
- All manifests live in `clusters/prod/apps/<namespace>/`
- Each app directory has a `kustomization.yaml` listing all resources
- Namespace defined in `namespace.yaml` within each app directory
- ConfigMaps for application config, Secrets for credentials
- Ingress rules defined per-app with TLS via cert-manager
- Git: conventional commits (feat|fix|chore|refactor)

## Don't / Do Instead
- Raw `kubectl apply -f` on single files -> `kubectl apply -k` with Kustomize
- Secrets in ConfigMaps -> K8s Secrets (opaque or TLS)
- `:latest` image tags -> commit SHA tags
- `kubectl edit` in production -> edit manifest, commit, apply
- hostPath volumes -> PVCs with proper storage class
- Missing resource limits -> always set requests and limits

## Agent Delegation
- @deploy-validator: MUST run before any deployment. Validates manifests, images, resource limits
- @security-auditor: RBAC review, secret management, container security, network policies
- @cybersecurity-engineer: threat modeling, K3s hardening, ingress security
- @systems-architect: namespace design, storage strategy, scaling decisions, ADRs
- @data-engineer: TimescaleDB schema, backup strategy, query optimization

## Related Repos
- Application code: `/home/sudhan0312/Desktop/algo-trading-system/`
- This repo manages infrastructure only; application logic lives in the trading system repo

## Memory Management
- Before ending any session, update MEMORY.md with: date, decisions, changes applied
- Keep entries as one-liners; details go to topic files in notes/
