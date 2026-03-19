---
paths:
  - clusters/**/*
  - "*.yaml"
  - "*.yml"
---

# Infrastructure Rules

- Always use Kustomize for resource composition; never apply individual manifests directly
- Never hardcode secrets in manifests; use K8s Secrets objects (referenced via secretKeyRef)
- All deployments MUST have resource requests AND limits (cpu + memory) on every container
- Use PriorityClasses to control OOM kill ordering (databases > app services > batch jobs)
- Namespace isolation: trading workloads MUST be in the `trading` namespace, never `default`
- Image tags must be commit SHAs, not `:latest` (exception: orchestrator during active dev)
- PVCs must specify storageClassName and accessModes explicitly
- Every kustomization.yaml must list ALL resources in the directory; no orphaned manifests
- Labels: always include `app`, `component`, and `part-of` on every resource
- Annotations: Prometheus scrape annotations on all service pods (`prometheus.io/scrape: "true"`)
- ConfigMaps for application config only; secrets go in Secret objects
- Ingress resources must reference TLS secrets managed by cert-manager
- CronJobs must have `concurrencyPolicy: Forbid` unless parallel execution is explicitly safe
