# cluster-infra (Flux GitOps)

Manifests for deploying blog-site to K3s with Traefik.

## Apply
Flux is bootstrapped to `./clusters/prod`.
Ensure the `web` namespace and Docker Hub pull secret exist:
```bash
kubectl create namespace web --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry dockerhub-creds   --docker-server=https://index.docker.io/v1/   --docker-username="sudhan03"   --docker-password="<YOUR_DOCKER_HUB_TOKEN>"   --docker-email="you@example.com"   -n web
```
Then commit & push this repo. Flux will reconcile automatically.
# my-blog-site-cluster-infra
