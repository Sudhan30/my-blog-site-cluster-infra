# Security Fix - Secret Management

## Overview
All hardcoded credentials have been replaced with Kubernetes Secrets for security.

## Files Changed
- `clusters/prod/apps/backend/deployment.yaml` - Now uses `backend-secrets` 
- `clusters/prod/apps/monitoring/postgres-exporter-deployment.yaml` - Now uses `backend-secrets`
- `clusters/prod/apps/monitoring/grafana-secret.yaml` - Template only, actual secret in cluster
- `docker-compose.yml` - Added dev-only warning

## Required Actions

### 1. Create Secrets in Cluster

Run this script on your server **BEFORE** deploying:

```bash
./create-secrets.sh
```

This will:
- Generate strong random passwords
- Create `backend-secrets` in the `web` namespace
- Backup existing secrets
- Provide PostgreSQL password update commands

### 2. Update PostgreSQL Password

After running the script, update the database password:

```bash
POSTGRES_POD=$(kubectl get pods -n web -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POSTGRES_POD -n web -- psql -U postgres

# In psql:
ALTER USER blog_user WITH PASSWORD 'NEW_PASSWORD_FROM_SCRIPT';
\q
```

### 3. Deploy Changes

The updated deployment files will be auto-deployed by Flux after pushing to main.

### 4. Verify

```bash
# Check secret exists
kubectl get secret backend-secrets -n web

# Check pods are running
kubectl get pods -n web

# Test backend API
curl https://api.sudharsana.dev/health
```

## Secret Contents

The `backend-secrets` secret contains:
- `database-url` - Full PostgreSQL connection string
- `database-password` - Just the password (for reference)
- `jwt-secret` - JWT signing secret

## Security Improvements

✅ No credentials in Git history (going forward)
✅ Strong randomly generated passwords
✅ Kubernetes native secret management
✅ Easy credential rotation
