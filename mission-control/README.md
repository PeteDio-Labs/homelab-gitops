# Mission Control - GitOps Manifests

Kubernetes manifests for deploying Mission Control (backend + frontend + PostgreSQL) via ArgoCD.

## Structure

```
mission-control/
├── base/                      # Base Kubernetes manifests
│   ├── namespace.yaml
│   ├── backend/               # Node.js/Express API
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml        # Template only (git-ignored)
│   │   └── kustomization.yaml
│   ├── postgresql/            # PostgreSQL StatefulSet
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── secret.yaml        # Template only (git-ignored)
│   │   └── kustomization.yaml
│   ├── frontend/              # Next.js Web UI
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   └── kustomization.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── sealed-secrets/    # Encrypted secrets (safe to commit)
│   │       ├── backend-secrets.yaml
│   │       ├── postgresql-secret.yaml
│   │       └── kustomization.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── sealed-secrets/
├── scripts/
│   └── generate-sealed-secrets.sh  # Generates and seals all secrets
├── argocd/
│   ├── project.yaml
│   └── applications/
│       ├── mission-control-dev.yaml
│       └── mission-control-prod.yaml
├── SEALED-SECRETS.md
└── README.md
```

## Deployment

### Prerequisites

1. **MicroK8s cluster** with ArgoCD installed
2. **Sealed Secrets** controller (for production secrets)
3. **Docker registry** credentials configured (Nexus or docker.toastedbytes.com)
4. **Backend built and pushed** to registry

### Step 1: Generate Sealed Secrets

```bash
cd /path/to/gitops/gitops/mission-control

# For dev
./scripts/generate-sealed-secrets.sh dev

# For prod
./scripts/generate-sealed-secrets.sh prod
```

The script generates random credentials and prompts for your Gemini API key, then encrypts everything with `kubeseal`. Save the displayed plaintext credentials in your password manager.

See [SEALED-SECRETS.md](SEALED-SECRETS.md) for full details.

### Step 2: Update ConfigMap

Edit [`base/backend/configmap.yaml`](base/backend/configmap.yaml):

```yaml
# Update these values with your actual endpoints
PROXMOX_HOST: "https://192.168.50.10:8006"
PROMETHEUS_URL: "http://prometheus-server.observability-stack:9090"
OLLAMA_BASE_URL: "http://ollama.dev:11434"
ARGOCD_SERVER: "argocd-server.argocd:443"
```

### Step 3: Apply ArgoCD Project and Applications

```bash
# Apply ArgoCD project
kubectl apply -f argocd/project.yaml

# Deploy dev environment
kubectl apply -f argocd/applications/mission-control-dev.yaml

# (Optional) Deploy prod environment
kubectl apply -f argocd/applications/mission-control-prod.yaml
```

### Step 4: Monitor Deployment

```bash
# Watch ArgoCD sync
argocd app get mission-control-dev
argocd app sync mission-control-dev

# Watch pods
kubectl get pods -n mission-control -w

# Check logs
kubectl logs -n mission-control -l app=mission-control-backend -f
```

### Step 5: Access Mission Control

**Via Ingress** (if DNS configured):
```
http://mission-control.homelab.local
```

**Via Port Forward** (for testing):
```bash
# Frontend
kubectl port-forward -n mission-control svc/mission-control-frontend 8080:80

# Backend
kubectl port-forward -n mission-control svc/mission-control-backend 3000:3000

# Access at http://localhost:8080
```

## Environments

### Dev

- **Image tags**: `develop-latest`
- **Replicas**: 1 backend, 1 frontend
- **Auto-sync**: Enabled
- **Log level**: debug
- **Node ENV**: development

### Prod

- **Image tags**: `main-latest`
- **Replicas**: 2 backend, 2 frontend
- **Auto-sync**: Manual (self-heal disabled)
- **Log level**: info
- **Node ENV**: production
- **Resources**: Higher CPU/memory limits

## Secrets Management

All secrets are managed via **Sealed Secrets**. Plaintext `secret.yaml` files in `base/` are git-ignored templates only.

### Required Secrets

**`backend-secrets`** (SealedSecret → consumed via `envFrom: secretRef`):
- `PROXMOX_API_TOKEN`: Proxmox API token
- `GEMINI_API_KEY`: Google Gemini API key
- `API_AUTH_TOKEN`: Backend auth token (for web/macOS app)
- `POSTGRES_PASSWORD`: PostgreSQL database password

**`postgresql-secret`** (SealedSecret → consumed via `secretKeyRef`):
- `password`: PostgreSQL database password (same value as above)

### Generating / Rotating Secrets

```bash
./scripts/generate-sealed-secrets.sh dev   # or prod
git add overlays/
git commit -m "chore: rotate sealed secrets"
git push
```

See [SEALED-SECRETS.md](SEALED-SECRETS.md) for full guide.

## Troubleshooting

### Pods stuck in `Pending`

```bash
kubectl describe pod <pod-name> -n mission-control
# Check events for storage/resource issues
```

### Backend can't connect to PostgreSQL

```bash
# Verify PostgreSQL is running
kubectl get pods -n mission-control -l app=postgresql

# Check logs
kubectl logs -n mission-control postgresql-0

# Test connection from backend pod
kubectl exec -it -n mission-control <backend-pod> -- sh
nc -zv postgresql 5432
```

### Image pull errors

```bash
# Verify image exists in registry
curl https://docker.toastedbytes.com/v2/mission-control-backend/tags/list

# Check imagePullSecret
kubectl get secret nexus-registry -n mission-control
```

### ArgoCD sync fails

```bash
# Check ArgoCD app status
argocd app get mission-control-dev

# View sync errors
argocd app sync mission-control-dev --dry-run

# Force sync
argocd app sync mission-control-dev --force
```

## Updating Image Tags

ArgoCD Image Updater will automatically update tags when new images are pushed (if configured).

**Manual update**:
```bash
# Edit overlay kustomization
cd overlays/dev
kustomize edit set image docker.toastedbytes.com/mission-control-backend:v1.2.3

# Commit and push
git add kustomization.yaml
git commit -m "Update backend to v1.2.3"
git push

# ArgoCD will auto-sync
```

## References

- [Mission Control Master Plan](../../mission%20control/MISSION_CONTROL_MASTER_PLAN.md)
- [Backend Repo](https://github.com/petedillo/mission-control-backend)
- [Frontend Repo](https://github.com/petedillo/mission-control-web)
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [Kustomize Docs](https://kustomize.io/)
