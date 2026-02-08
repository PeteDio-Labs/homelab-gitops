# Mission Control - Sealed Secrets Setup

This guide explains how to securely manage secrets for Mission Control using Sealed Secrets.

## Prerequisites

- `kubectl` configured with access to your cluster
- `kubeseal` CLI installed ([installation guide](https://github.com/bitnami-labs/sealed-secrets#installation))
- Sealed Secrets controller deployed in your cluster

## Quick Start

### 1. Generate Sealed Secrets

For **dev** environment:
```bash
cd /path/to/gitops/gitops/mission-control
./scripts/generate-sealed-secrets.sh dev
```

For **prod** environment:
```bash
./scripts/generate-sealed-secrets.sh prod
```

The script will:
- Prompt you for your Gemini API Key (or use a placeholder)
- Generate random secure tokens for Proxmox, Auth, and PostgreSQL
- Encrypt them with Sealed Secrets (safe to commit to Git)
- Display all credentials for your records

**⚠️ CRITICAL**: Save the displayed credentials in your password manager! You won't be able to recover them.

### 2. Commit and Push

```bash
git add overlays/
git commit -m "feat: add sealed secrets for mission-control"
git push
```

ArgoCD will automatically:
- Detect the changes
- Deploy sealed secrets to the cluster
- The Sealed Secrets controller will decrypt them
- Pods will have access to the plain secrets via environment variables

## Secrets Structure

The generated secrets are organized into two sealed secrets that match the names expected by the Kubernetes manifests:

1. **backend-secrets.yaml** - SealedSecret named `backend-secrets` containing: `PROXMOX_API_TOKEN`, `GEMINI_API_KEY`, `API_AUTH_TOKEN`, `POSTGRES_PASSWORD`. Consumed by the backend deployment via `envFrom: secretRef`.
2. **postgresql-secret.yaml** - SealedSecret named `postgresql-secret` containing: `password`. Consumed by both the backend deployment and PostgreSQL statefulset via `secretKeyRef`.

## Getting Your Gemini API Key

1. Visit https://makersuite.google.com/app/apikey
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the key and use it when running the sealed-secrets script

## Verification

After deployment, verify secrets are created:

```bash
# Check sealed secrets
kubectl get sealedsecrets -n mission-control

# Check decrypted secrets
kubectl get secrets -n mission-control

# View secret keys (not values)
kubectl describe secret backend-secrets -n mission-control
kubectl describe secret postgresql-secret -n mission-control
```

## Updating Secrets

To update a secret:

1. Re-run the script for the specific environment
2. Commit the updated sealed-secret.yaml files
3. Push to trigger ArgoCD sync
4. The sealed-secrets controller will automatically update the secrets

## Security Notes

- ✅ Sealed secrets are encrypted and **safe to commit** to Git
- ✅ Only the Sealed Secrets controller in your cluster can decrypt them
- ❌ **Never commit** plain `secret.yaml` files
- ❌ The `base/backend/secret.yaml` and `base/postgresql/secret.yaml` are git-ignored and serve as templates only
- 🔒 Store plain credentials in a password manager (1Password, Bitwarden, etc.)

## Troubleshooting

### Sealed secret won't decrypt
- Ensure the Sealed Secrets controller is running: `kubectl get pods -n kube-system | grep sealed-secrets`
- Check if the certificate matches: the sealed secret must be encrypted with the current controller's cert

### Need to rotate secrets
1. Delete the sealed secret: `kubectl delete sealedsecret <name> -n mission-control`
2. Re-run the generation script
3. Commit and push the new sealed secret
4. Restart affected pods: `kubectl rollout restart deployment mission-control-backend -n mission-control`

## Reference

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Bitnami Sealed Secrets Docs](https://docs.bitnami.com/tutorials/sealed-secrets/)
