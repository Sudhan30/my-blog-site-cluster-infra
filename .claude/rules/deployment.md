---
paths:
  - clusters/**/*
  - "*.yaml"
  - "*.yml"
---

# Deployment Rules

- Always check current pod status (`kubectl get pods -n <namespace>`) before deploying
- Verify image exists in Docker Hub before updating image tag in manifest
- Update `kustomization.yaml` when adding or removing resource files
- Test with `kubectl apply -k <path> --dry-run=client` before applying
- Preview changes with `kubectl diff -k <path>` to confirm expected diff
- Monitor pod startup after deployment: `kubectl get pods -n <namespace> -w`
- Rollback procedure: `git revert <commit>` then `flux reconcile kustomization flux-system`
- Never apply directly to production without reviewing the full diff
- Database deployments (TimescaleDB, Redis) require extra caution; verify PVC is not recreated
- After deployment, verify endpoints respond: check ingress routes and service ports
- CronJob changes: verify next scheduled run with `kubectl get cronjob -n <namespace>`
- Log deployment actions to MEMORY.md: date, namespace, what changed, rollback plan
