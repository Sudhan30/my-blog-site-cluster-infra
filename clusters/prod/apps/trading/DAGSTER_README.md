# Dagster Orchestration Setup

## Overview

Dagster is deployed in the `trading` namespace to orchestrate market data pipelines and scheduled jobs for the algorithmic trading system.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Dagster Deployment                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐   ┌──────────────────────┐       │
│  │  dagster-webserver   │   │   dagster-daemon     │       │
│  │  (UI - Port 3000)    │   │   (Scheduler/Runner) │       │
│  └──────────────────────┘   └──────────────────────┘       │
│           │                           │                     │
│           └───────────┬───────────────┘                     │
│                       │                                     │
│              ┌────────▼────────┐                            │
│              │  dagster.yaml   │                            │
│              │  (ConfigMap)    │                            │
│              └─────────────────┘                            │
│                       │                                     │
│         ┌─────────────┼─────────────┐                       │
│         │             │             │                       │
│    ┌────▼───┐   ┌────▼────┐   ┌───▼────┐                  │
│    │ K8s Job│   │PostgreSQL│   │ Redis  │                  │
│    │ Pods   │   │ Storage │   │ Cache  │                  │
│    └────────┘   └─────────┘   └────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Dagster Webserver
- **Purpose**: Web UI for monitoring and triggering jobs
- **Port**: 3000
- **Ingress**: http://dagster-suddu.duckdns.org
- **Command**: `dagster-webserver -h 0.0.0.0 -p 3000 -f orchestrator/__init__.py`

### 2. Dagster Daemon
- **Purpose**: Runs scheduled jobs and manages run queue
- **Command**: `dagster-daemon run -f orchestrator/__init__.py`
- **Responsibilities**:
  - Execute scheduled jobs (e.g., daily market data backfill at 6:00 AM UTC)
  - Launch runs as K8s jobs
  - Manage run queue

### 3. K8sRunLauncher
- **Purpose**: Launch each Dagster run as a separate Kubernetes Job
- **Benefits**:
  - Isolation: Each run in its own pod
  - Resource management: Per-run resource limits
  - Failure isolation: One run failure doesn't affect others

## Configuration Files

### configmap-dagster.yaml
Contains the Dagster instance configuration:

**Key Settings**:
- `instance_config_map: dagster-instance` - **REQUIRED** for K8sRunLauncher
- `job_namespace: trading` - Where job pods are created
- `job_image: docker.io/sudhan03/algo-trading:portfolio-tracker-*` - Container image for runs
- Storage: PostgreSQL (TimescaleDB)
- Run launcher: K8sRunLauncher

**Common Issues Fixed** (2026-01-31):
- ❌ `namespace: trading` → ✅ `job_namespace: trading`
- ❌ Missing `instance_config_map` → ✅ Added `instance_config_map: dagster-instance`
- ❌ Missing `load_incluster_config` → ✅ Added `load_incluster_config: true`

### deployment-dagster.yaml
Kubernetes deployment manifest:
- 2 containers: webserver + daemon
- Mounts `dagster-instance` ConfigMap to `/app/dagster_home/dagster.yaml`
- Uses `dagster` service account for K8s API access
- NodePort service on port 30030
- Ingress for external access

### rbac-dagster.yaml
RBAC configuration:
- **ServiceAccount**: `dagster`
- **Role**: `dagster-role`
  - Pods: create, delete, get, list, watch, patch, update
  - Jobs: create, delete, get, list, watch, patch, update
  - ConfigMaps: get, list (read-only)
  - Secrets: get, list (read-only)
- **RoleBinding**: `dagster-role-binding`

## Deployment

### Apply All Manifests
```bash
# From cluster-infra repo root
kubectl apply -f clusters/prod/apps/trading/rbac-dagster.yaml
kubectl apply -f clusters/prod/apps/trading/configmap-dagster.yaml
kubectl apply -f clusters/prod/apps/trading/deployment-dagster.yaml
```

### Update Configuration Only
```bash
kubectl apply -f clusters/prod/apps/trading/configmap-dagster.yaml
kubectl rollout restart deployment/dagster -n trading
```

### Verify Deployment
```bash
# Check pod status
kubectl get pods -n trading -l app=dagster

# Check logs
kubectl logs -f deployment/dagster -n trading -c dagster-daemon
kubectl logs -f deployment/dagster -n trading -c dagster-webserver

# Check service
kubectl get svc dagster -n trading

# Check ingress
kubectl get ingress dagster-ingress -n trading
```

## Schedules

### market_data_schedule
- **Cron**: `0 6 * * *` (Daily at 6:00 AM UTC)
- **Job**: `market_data_job`
- **Assets**: Market data backfill and integrity checks
- **Defined in**: `algo-trading-system/orchestrator/__init__.py`

## Troubleshooting

### Issue: DagsterInvalidConfigError - "namespace" at root
**Cause**: Using `namespace` instead of `job_namespace` in K8sRunLauncher config

**Fix**: Update configmap-dagster.yaml:
```yaml
# ❌ Wrong
config:
  namespace: trading

# ✅ Correct
config:
  job_namespace: trading
```

### Issue: Missing instance_config_map
**Cause**: K8sRunLauncher requires `instance_config_map` field

**Fix**: Add to configmap-dagster.yaml:
```yaml
config:
  instance_config_map: dagster-instance  # Must match ConfigMap name
  job_namespace: trading
  # ... other config
```

### Issue: Runs not starting
**Checks**:
1. Daemon logs: `kubectl logs -f deployment/dagster -n trading -c dagster-daemon`
2. RBAC permissions: Ensure service account has job creation rights
3. ConfigMap mounted: Check volume mounts in pod
4. Image exists: Verify docker image is accessible

### Issue: Permission denied creating jobs
**Fix**: Verify RBAC:
```bash
kubectl get role dagster-role -n trading -o yaml
kubectl get rolebinding dagster-role-binding -n trading -o yaml
```

Ensure role includes:
```yaml
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create", "delete", "get", "list", "watch"]
```

## Monitoring

### Access Dagster UI
- **URL**: http://dagster-suddu.duckdns.org
- **Features**:
  - View scheduled runs
  - Manually trigger jobs
  - View run logs
  - Monitor asset materializations

### Metrics
Monitor via Grafana dashboards:
- Dagster run success/failure rate
- Run duration
- Schedule execution times

### Logs
```bash
# Real-time daemon logs
kubectl logs -f deployment/dagster -n trading -c dagster-daemon

# Real-time webserver logs
kubectl logs -f deployment/dagster -n trading -c dagster-webserver

# Check specific run job logs
kubectl logs job/<dagster-run-id> -n trading
```

## Development

### Local Testing
Use development mode configuration (SQLite-based) for local testing:
```bash
# In algo-trading-system repo
dagster dev -f orchestrator/__init__.py
```

This uses `DefaultRunLauncher` instead of K8sRunLauncher.

### Adding New Schedules
1. Define schedule in `orchestrator/__init__.py`:
   ```python
   new_schedule = ScheduleDefinition(
       job=my_job,
       cron_schedule="0 12 * * *",
   )

   defs = Definitions(
       assets=all_assets,
       schedules=[market_data_schedule, new_schedule],
   )
   ```

2. Rebuild and push image:
   ```bash
   docker build -t sudhan03/algo-trading:portfolio-tracker-<tag> -f Dockerfile.portfolio-tracker .
   docker push sudhan03/algo-trading:portfolio-tracker-<tag>
   ```

3. Update image tag in `deployment-dagster.yaml` and apply:
   ```bash
   kubectl apply -f clusters/prod/apps/trading/deployment-dagster.yaml
   ```

## Configuration Reference

### K8sRunLauncher Fields

| Field | Required | Description |
|-------|----------|-------------|
| `instance_config_map` | ✅ Yes | Name of ConfigMap containing dagster.yaml |
| `job_namespace` | ✅ Yes | Namespace for job pods |
| `job_image` | No | Docker image (defaults to webserver image) |
| `service_account_name` | No | Service account for jobs |
| `image_pull_policy` | No | Always/IfNotPresent/Never |
| `load_incluster_config` | No | Use in-cluster K8s config (default: true) |
| `env_config_maps` | No | List of ConfigMaps to mount as env vars |
| `env_secrets` | No | List of Secrets to mount as env vars |

### Storage Backends

**Current**: PostgreSQL (recommended for production)
```yaml
storage:
  postgres:
    postgres_db:
      hostname: timescaledb
      username: { env: DB_USER }
      password: { env: DB_PASSWORD }
      db_name: trading_db
      port: 5432
```

**Alternative**: SQLite (for local dev only)
```yaml
run_storage:
  module: dagster.core.storage.runs
  class: SqliteRunStorage
  config:
    base_dir: /app/dagster_home/storage
```

## Resources

- **Dagster Docs**: https://docs.dagster.io
- **K8sRunLauncher**: https://docs.dagster.io/deployment/guides/kubernetes/deploying-with-helm
- **Repo**: https://github.com/sudhan03/algo-trading-system
- **Cluster Infra**: This repository

## Change Log

### 2026-01-31: Configuration Fix
- **Issue**: `DagsterInvalidConfigError` with incorrect K8sRunLauncher config
- **Changes**:
  - Fixed: `namespace` → `job_namespace`
  - Added: `instance_config_map` field (required)
  - Added: `load_incluster_config: true`
  - Enhanced RBAC with ConfigMap and Secret read permissions
- **Impact**: Dagster daemon can now successfully launch runs as K8s jobs
