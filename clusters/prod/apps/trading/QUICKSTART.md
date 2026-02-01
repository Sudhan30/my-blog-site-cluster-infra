# Dagster Quick Fix Guide

## Problem Fixed (2026-01-31)

```
DagsterInvalidConfigError:
  Error 1: Received unexpected config entry "namespace" at the root
  Error 2: Missing required config entry "instance_config_map" at the root
```

## Solution Applied

### Files Modified

#### 1. [configmap-dagster.yaml](configmap-dagster.yaml)

**Changes**:
- ✅ `namespace: trading` → `job_namespace: trading`
- ✅ Added `instance_config_map: dagster-instance`
- ✅ Added `load_incluster_config: true`
- ✅ Added comments for clarity

**Before**:
```yaml
config:
  namespace: trading  # ❌ Wrong field name
  # ❌ Missing instance_config_map
```

**After**:
```yaml
config:
  instance_config_map: dagster-instance  # ✅ Required
  job_namespace: trading                  # ✅ Correct field
  load_incluster_config: true             # ✅ Added
```

#### 2. [rbac-dagster.yaml](rbac-dagster.yaml)

**Enhancements**:
- ✅ Added `patch` and `update` verbs for pods and jobs
- ✅ Added ConfigMap read permissions
- ✅ Added Secret read permissions

### Deploy the Fix

```bash
# 1. Apply updated ConfigMap
kubectl apply -f configmap-dagster.yaml

# 2. Restart Dagster to pick up new config
kubectl rollout restart deployment/dagster -n trading

# 3. Monitor rollout
kubectl rollout status deployment/dagster -n trading

# 4. Check logs
kubectl logs -f deployment/dagster -n trading -c dagster-daemon
```

### Verify Success

```bash
# Check pod is running
kubectl get pods -n trading -l app=dagster

# Should show:
# NAME                       READY   STATUS    RESTARTS   AGE
# dagster-xxxxxxxxxx-xxxxx   2/2     Running   0          30s

# Check logs for errors
kubectl logs deployment/dagster -n trading -c dagster-daemon --tail=50

# Should NOT show:
# - DagsterInvalidConfigError
# - "Received unexpected config entry 'namespace'"
# - "Missing required config entry 'instance_config_map'"
```

### Access Dagster UI

```bash
# Forward port (if ingress not working)
kubectl port-forward svc/dagster -n trading 3000:3000

# Or use ingress
open http://dagster-suddu.duckdns.org
```

## Configuration Reference

### K8sRunLauncher Required Fields

| Field | Value | Purpose |
|-------|-------|---------|
| `instance_config_map` | `dagster-instance` | ConfigMap name (must match metadata.name) |
| `job_namespace` | `trading` | Where to create job pods |
| `service_account_name` | `dagster` | Service account for jobs |
| `job_image` | `docker.io/sudhan03/algo-trading:portfolio-tracker-*` | Container image for runs |

### Common Field Name Mistakes

| ❌ Wrong | ✅ Correct | Notes |
|---------|-----------|-------|
| `namespace` | `job_namespace` | Must use `job_namespace` |
| `image` | `job_image` | Must use `job_image` |
| `kube_config_file` | `kubeconfig_file` | If using custom kubeconfig |

## Rollback (If Needed)

```bash
# Rollback to previous deployment
kubectl rollout undo deployment/dagster -n trading

# Check rollback status
kubectl rollout status deployment/dagster -n trading
```

## Testing

### 1. Trigger a Test Run

From Dagster UI:
1. Navigate to http://dagster-suddu.duckdns.org
2. Go to "Jobs" → `market_data_job`
3. Click "Launchpad"
4. Click "Launch Run"

### 2. Monitor Run

```bash
# List all jobs in namespace
kubectl get jobs -n trading

# Should see a new job like:
# dagster-run-12345678-1234-1234-1234-123456789012

# Check job pod logs
kubectl logs job/dagster-run-<id> -n trading
```

### 3. Verify Run Completed

In Dagster UI:
- Run should show "SUCCESS" status
- Assets should be materialized
- Logs should be visible

## Troubleshooting

### Still getting errors?

**Check ConfigMap is mounted**:
```bash
kubectl exec -it deployment/dagster -n trading -c dagster-daemon -- cat /app/dagster_home/dagster.yaml
```

Should show the corrected configuration.

**Check RBAC**:
```bash
# Verify service account
kubectl get sa dagster -n trading

# Verify role
kubectl get role dagster-role -n trading -o yaml

# Test permissions
kubectl auth can-i create jobs --as=system:serviceaccount:trading:dagster -n trading
# Should return: yes
```

**Check image exists**:
```bash
docker pull docker.io/sudhan03/algo-trading:portfolio-tracker-latest
```

## Next Steps

1. ✅ Configuration fixed
2. ⏭️ Test scheduled run (wait for next 6:00 AM UTC)
3. ⏭️ Monitor for automatic execution
4. ⏭️ Review run logs and metrics

## Additional Documentation

- **Full Guide**: [DAGSTER_README.md](DAGSTER_README.md)
- **Config Examples**: [configs/](configs/)
  - `dagster-dev-mode.yaml` - SQLite + DefaultRunLauncher
  - `dagster-prod-mode.yaml` - PostgreSQL + K8sRunLauncher
- **Dagster Official Docs**: https://docs.dagster.io/deployment/guides/kubernetes

## Support

If issues persist:
1. Check [DAGSTER_README.md](DAGSTER_README.md) troubleshooting section
2. Review Dagster daemon logs
3. Verify all environment variables are set correctly
4. Ensure TimescaleDB is accessible from Dagster pods
