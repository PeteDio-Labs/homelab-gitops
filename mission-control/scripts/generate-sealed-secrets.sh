#!/bin/bash

# generate-sealed-secrets.sh
# Securely generates sealed secrets for mission-control environments
# These sealed secrets can be safely committed to Git

set -e

ENVIRONMENT="${1:-dev}"
NAMESPACE="mission-control"
OVERLAY_PATH="overlays/${ENVIRONMENT}/sealed-secrets"

echo "🔐 Generating sealed secrets for: ${ENVIRONMENT}"
echo "📦 Namespace: ${NAMESPACE}"
echo "📁 Output: ${OVERLAY_PATH}"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create sealed-secrets directory if it doesn't exist
mkdir -p "${OVERLAY_PATH}"

# 1. Generate Proxmox API Token
echo -e "${YELLOW}[1/4]${NC} Generating Proxmox API Token..."
PROXMOX_TOKEN=$(openssl rand -hex 32)
kubectl create secret generic backend-secrets-proxmox \
  --namespace="${NAMESPACE}" \
  --from-literal=PROXMOX_API_TOKEN="${PROXMOX_TOKEN}" \
  --dry-run=client \
  -o yaml | kubeseal -o yaml > "${OVERLAY_PATH}/proxmox-token.yaml"
echo -e "${GREEN}✓${NC} Proxmox API token sealed"

# 2. Generate Gemini API Key secret (user will need to provide the actual key)
echo -e "${YELLOW}[2/4]${NC} Generating Gemini API Key secret..."
read -p "Enter your Gemini API Key (or press Enter to use placeholder): " GEMINI_KEY
if [ -z "$GEMINI_KEY" ]; then
  GEMINI_KEY="REPLACE_WITH_YOUR_GEMINI_API_KEY"
fi
kubectl create secret generic backend-secrets-gemini \
  --namespace="${NAMESPACE}" \
  --from-literal=GEMINI_API_KEY="${GEMINI_KEY}" \
  --dry-run=client \
  -o yaml | kubeseal -o yaml > "${OVERLAY_PATH}/gemini-api-key.yaml"
echo -e "${GREEN}✓${NC} Gemini API key sealed"

# 3. Generate Backend Auth Token
echo -e "${YELLOW}[3/4]${NC} Generating Backend Auth Token..."
API_TOKEN=$(openssl rand -hex 32)
kubectl create secret generic backend-secrets-auth \
  --namespace="${NAMESPACE}" \
  --from-literal=API_AUTH_TOKEN="${API_TOKEN}" \
  --dry-run=client \
  -o yaml | kubeseal -o yaml > "${OVERLAY_PATH}/auth-token.yaml"
echo -e "${GREEN}✓${NC} Backend auth token sealed"

# 4. Generate PostgreSQL Password
echo -e "${YELLOW}[4/4]${NC} Generating PostgreSQL Password..."
POSTGRES_PASS=$(openssl rand -base64 32)
kubectl create secret generic backend-secrets-postgres \
  --namespace="${NAMESPACE}" \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASS}" \
  --dry-run=client \
  -o yaml | kubeseal -o yaml > "${OVERLAY_PATH}/postgres-password.yaml"
echo -e "${GREEN}✓${NC} PostgreSQL password sealed"

#############################################
# Summary
#############################################

echo ""
echo -e "${GREEN}✅ All sealed secrets generated successfully!${NC}"
echo ""
echo "📋 Generated Files:"
echo "  - ${OVERLAY_PATH}/proxmox-token.yaml"
echo "  - ${OVERLAY_PATH}/gemini-api-key.yaml"
echo "  - ${OVERLAY_PATH}/auth-token.yaml"
echo "  - ${OVERLAY_PATH}/postgres-password.yaml"
echo ""
echo "⚠️  IMPORTANT - Save these credentials securely:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PROXMOX_API_TOKEN: ${PROXMOX_TOKEN}"
echo "GEMINI_API_KEY: ${GEMINI_KEY}"
echo "API_AUTH_TOKEN: ${API_TOKEN}"
echo "POSTGRES_PASSWORD: ${POSTGRES_PASS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ These sealed secrets are encrypted and safe to commit to Git"
echo ""
echo "📝 Next steps:"
echo "  1. Update overlays/${ENVIRONMENT}/kustomization.yaml to include these sealed secrets"
echo "  2. Commit and push to trigger ArgoCD deployment"
