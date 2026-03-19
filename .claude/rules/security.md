---
paths:
  - clusters/**/*
  - "*.yaml"
  - "*.yml"
---

# Security Rules

- Secrets MUST be K8s Secret objects, never ConfigMaps or plaintext in manifests
- No privileged containers (`securityContext.privileged: false` enforced)
- All containers run as non-root (`runAsNonRoot: true`, `runAsUser: 1000` or higher)
- Network policies restrict cross-namespace traffic; default-deny ingress per namespace
- RBAC: least-privilege ServiceAccounts; never use `cluster-admin` for application workloads
- TLS everywhere: cert-manager + Let's Encrypt for all ingress; no plain HTTP endpoints
- Docker images: use minimal base images (alpine, distroless); pin exact versions
- No hostPath volumes except for monitoring DaemonSets (Promtail log collection)
- Secret references in environment variables use `secretKeyRef`, never `value:` with inline secrets
- Container images pulled from trusted registries only (Docker Hub `sudhan03/` namespace)
- `readOnlyRootFilesystem: true` where possible; use emptyDir for writable temp paths
- Drop all Linux capabilities by default (`drop: ["ALL"]`), add back only what is needed
- Never commit `.env` files, credential files, or TLS private keys to this repository
