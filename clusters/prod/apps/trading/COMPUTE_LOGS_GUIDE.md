# Dagster Compute Logs Configuration Guide

## Current Situation ⚠️

**Your Dagster instance does NOT have persistent compute log storage configured.**

### What This Means:

| Log Type | Storage Location | Persistence |
|----------|------------------|-------------|
| **Run metadata** (status, timestamps) | ✅ PostgreSQL | Permanent |
| **Event logs** (step events, errors) | ✅ PostgreSQL | Permanent |
| **Compute logs** (stdout/stderr, print statements) | ❌ Pod ephemeral storage | **Lost when pod deleted** |

### Current Access:

```bash
# You can ONLY view logs while the job pod exists
kubectl logs dagster-run-<run-id>-xxxxx -n trading

# Once the pod is deleted, logs are GONE
kubectl delete pod dagster-run-<run-id>-xxxxx -n trading  # ⚠️ Logs lost!
```

---

## Recommended Solutions

### Option 1: S3/MinIO Storage (Production Grade) ⭐

**Best for**: Production environments, large log volumes, long-term retention

**Pros**:
- ✅ Scalable - no storage limits
- ✅ Durable - logs never lost
- ✅ Cost-effective for large volumes
- ✅ Can integrate with existing S3/MinIO

**Cons**:
- Requires S3-compatible storage
- Needs AWS credentials management

**Setup**:

1. **Install MinIO** (if you don't have S3):
   ```bash
   # Quick MinIO deployment
   kubectl apply -f https://raw.githubusercontent.com/minio/minio/master/docs/orchestration/kubernetes/minio-standalone-pvc.yaml
   ```

2. **Create S3 bucket**:
   ```bash
   # Using MinIO CLI
   mc alias set myminio http://minio:9000 minioadmin minioadmin
   mc mb myminio/dagster-compute-logs
   ```

3. **Add credentials to trading-secrets**:
   ```bash
   kubectl create secret generic trading-secrets \
     --from-literal=AWS_ACCESS_KEY_ID=minioadmin \
     --from-literal=AWS_SECRET_ACCESS_KEY=minioadmin \
     --from-literal=S3_ENDPOINT_URL=http://minio:9000 \
     --namespace=trading \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

4. **Update requirements.txt** in algo-trading-system repo:
   ```
   dagster-aws>=1.5.0
   ```

5. **Use config**: `configs/dagster-with-s3-logs.yaml`

---

### Option 2: Persistent Volume (Simple & K8s Native) 🎯

**Best for**: Getting started quickly, simpler infrastructure

**Pros**:
- ✅ Simple setup - pure Kubernetes
- ✅ No external dependencies
- ✅ Works with any K8s cluster
- ✅ Fast log access (local disk)

**Cons**:
- ⚠️ Storage limited by volume size
- ⚠️ Need to manage disk space
- ⚠️ Less scalable than S3

**Setup**:

1. **Create PVC**:
   ```bash
   kubectl apply -f clusters/prod/apps/trading/configs/dagster-logs-pvc.yaml
   ```

2. **Update Dagster deployment** to mount the PVC:
   ```yaml
   # Add to deployment-dagster.yaml
   volumes:
   - name: dagster-logs
     persistentVolumeClaim:
       claimName: dagster-logs-pvc

   # Add to both containers
   volumeMounts:
   - name: dagster-logs
     mountPath: /opt/dagster/logs
   ```

3. **Use config**: `configs/dagster-with-pvc-logs.yaml`

---

### Option 3: Azure Blob Storage

**Best for**: Azure-based infrastructure

```yaml
compute_logs:
  module: dagster_azure.blob.compute_log_manager
  class: AzureBlobComputeLogManager
  config:
    storage_account:
      env: AZURE_STORAGE_ACCOUNT
    container: dagster-compute-logs
    prefix: logs/
```

---

## Implementation Steps (Recommended: Option 2 - PVC)

### Step 1: Create PVC
```bash
cd ~/my-blog-site-cluster-infra
kubectl apply -f clusters/prod/apps/trading/configs/dagster-logs-pvc.yaml
```

### Step 2: Update Dagster Deployment

Add volume mounts to `deployment-dagster.yaml`:

```yaml
spec:
  template:
    spec:
      volumes:
      - name: dagster-instance
        configMap:
          name: dagster-instance
      # ADD THIS:
      - name: dagster-logs
        persistentVolumeClaim:
          claimName: dagster-logs-pvc

      containers:
      - name: dagster-webserver
        volumeMounts:
        - name: dagster-instance
          mountPath: /app/dagster_home/dagster.yaml
          subPath: dagster.yaml
        # ADD THIS:
        - name: dagster-logs
          mountPath: /opt/dagster/logs

      - name: dagster-daemon
        volumeMounts:
        - name: dagster-instance
          mountPath: /app/dagster_home/dagster.yaml
          subPath: dagster.yaml
        # ADD THIS:
        - name: dagster-logs
          mountPath: /opt/dagster/logs
```

### Step 3: Update ConfigMap

Replace your current `configmap-dagster.yaml` content with the content from `configs/dagster-with-pvc-logs.yaml`.

### Step 4: Apply Changes

```bash
# Apply PVC
kubectl apply -f clusters/prod/apps/trading/configs/dagster-logs-pvc.yaml

# Apply updated configmap
kubectl apply -f clusters/prod/apps/trading/configmap-dagster.yaml

# Apply updated deployment
kubectl apply -f clusters/prod/apps/trading/deployment-dagster.yaml

# Restart Dagster
kubectl rollout restart deployment/dagster -n trading
```

### Step 5: Verify

```bash
# Check PVC is bound
kubectl get pvc dagster-logs-pvc -n trading

# Trigger a test run and check logs persist
kubectl get pods -n trading -l dagster/job

# After run completes, delete the pod
kubectl delete pod dagster-run-xxxxx -n trading

# Logs should still be accessible in Dagster UI!
```

---

## Accessing Logs After Configuration

### Via Dagster UI
1. Navigate to a run
2. Click "Logs" tab
3. ✅ Logs persist even after pod deletion!

### Via kubectl (before configuration)
```bash
# ONLY works while pod exists
kubectl logs dagster-run-xxxxx -n trading
```

### Via PVC (after configuration)
```bash
# Directly access log files on the volume
kubectl exec -it deployment/dagster -n trading -c dagster-webserver -- \
  ls -lh /opt/dagster/logs/

# View specific log file
kubectl exec -it deployment/dagster -n trading -c dagster-webserver -- \
  cat /opt/dagster/logs/<run-id>/compute_logs/compute.stdout
```

---

## Log Cleanup

With persistent storage, you'll need to clean up old logs:

### Manual Cleanup
```bash
# Delete logs older than 30 days
kubectl exec -it deployment/dagster -n trading -c dagster-webserver -- \
  find /opt/dagster/logs -type f -mtime +30 -delete
```

### Automated Cleanup (Add to configmap)
```yaml
compute_logs:
  module: dagster.core.storage.local_compute_log_manager
  class: LocalComputeLogManager
  config:
    base_dir: /opt/dagster/logs
    # Auto-cleanup after 30 days
    upload_interval: 1
```

Or create a CronJob:
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dagster-log-cleanup
  namespace: trading
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command:
            - sh
            - -c
            - find /logs -type f -mtime +30 -delete
            volumeMounts:
            - name: dagster-logs
              mountPath: /logs
          volumes:
          - name: dagster-logs
            persistentVolumeClaim:
              claimName: dagster-logs-pvc
          restartPolicy: OnFailure
```

---

## Monitoring Log Storage

### Check PVC Usage
```bash
# See how much space is used
kubectl exec -it deployment/dagster -n trading -c dagster-webserver -- \
  df -h /opt/dagster/logs
```

### Alerts (Optional)
Set up monitoring alerts when log storage > 80% full.

---

## Summary

| Aspect | Current State | After PVC Setup | After S3 Setup |
|--------|--------------|-----------------|----------------|
| **Persistence** | ❌ Lost on pod deletion | ✅ Permanent | ✅ Permanent |
| **UI Access** | ❌ Only while pod alive | ✅ Always available | ✅ Always available |
| **Scalability** | N/A | ⚠️ Limited by volume | ✅ Unlimited |
| **Setup Complexity** | Simple | Medium | High |
| **Cost** | Free | PVC storage cost | S3 storage cost |
| **Recommended** | ❌ Not production-ready | ✅ Good for most cases | ⭐ Best for large scale |

---

## Quick Decision Guide

**Choose PVC** if:
- You want simple setup
- Log volume < 100GB
- You don't have S3/MinIO

**Choose S3/MinIO** if:
- Large log volumes (> 100GB)
- Long-term retention (> 3 months)
- Already using S3/MinIO
- Multi-cluster setup

---

## Reference Links

- [Dagster Compute Log Docs](https://docs.dagster.io/deployment/dagster-instance#compute-log-storage)
- [K8sRunLauncher Docs](https://docs.dagster.io/deployment/guides/kubernetes/deploying-with-helm#run-launcher)
- [S3 Log Manager](https://docs.dagster.io/_apidocs/libraries/dagster-aws#dagster_aws.s3.S3ComputeLogManager)
