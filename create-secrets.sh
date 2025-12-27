#!/bin/bash
# Security Fix: Create Kubernetes Secrets for Blog Infrastructure
# Run this on your server BEFORE deploying updated deployment files

set -e

echo "🔐 Creating Secure Kubernetes Secrets for Blog Infrastructure"
echo "=============================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Namespace
NAMESPACE="web"

# Function to generate strong password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to generate JWT secret
generate_jwt_secret() {
    openssl rand -base64 64 | tr -d "\n"
}

echo "📋 Step 1: Backup existing secrets (if any)"
echo "-------------------------------------------"
kubectl get secret backend-secrets -n $NAMESPACE -o yaml > /tmp/backend-secrets-backup-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || echo "No existing backend-secrets found (OK for first run)"
echo ""

echo "🔑 Step 2: Generate new credentials"
echo "-----------------------------------"
# Generate new passwords
DB_PASSWORD=$(generate_password)
JWT_SECRET=$(generate_jwt_secret)

# Construct database URL
DATABASE_URL="postgresql://blog_user:${DB_PASSWORD}@postgres-service:5432/blog_db?sslmode=disable"

echo -e "${GREEN}✓ Generated strong database password${NC}"
echo -e "${GREEN}✓ Generated strong JWT secret${NC}"
echo ""

echo "⚠️  IMPORTANT: Save these credentials securely!"
echo "=============================================="
echo "Database Password: $DB_PASSWORD"
echo "JWT Secret: $JWT_SECRET"
echo ""
read -p "Press ENTER to continue after saving these credentials..."
echo ""

echo "🚀 Step 3: Create Kubernetes Secret"
echo "-----------------------------------"
kubectl create secret generic backend-secrets \
  --from-literal=database-url="$DATABASE_URL" \
  --from-literal=database-password="$DB_PASSWORD" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Secret 'backend-secrets' created/updated in namespace '$NAMESPACE'${NC}"
echo ""

echo "📝 Step 4: Update PostgreSQL Password"
echo "-------------------------------------"
echo "You need to update the actual PostgreSQL password to match the new secret."
echo ""
echo "Run these commands:"
echo ""
echo "  # Connect to postgres pod"
echo "  POSTGRES_POD=\$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')"
echo "  kubectl exec -it \$POSTGRES_POD -n $NAMESPACE -- psql -U postgres"
echo ""
echo "  # In psql, run:"
echo "  ALTER USER blog_user WITH PASSWORD '$DB_PASSWORD';"
echo "  \\q"
echo ""
read -p "Press ENTER after updating PostgreSQL password..."
echo ""

echo "✅ Step 5: Verification"
echo "----------------------"
kubectl get secret backend-secrets -n $NAMESPACE
echo ""
echo -e "${GREEN}Secret created successfully!${NC}"
echo ""

echo "📋 Next Steps:"
echo "-------------"
echo "1. ✅ Secrets created in Kubernetes"
echo "2. ⏳ Update deployment files to reference these secrets"
echo "3. ⏳ Commit and push changes to Git"
echo "4. ⏳ Flux will auto-deploy updated configs"
echo "5. ⏳ Pods will restart with new secret references"
echo ""

echo "🔍 To verify the secret contents:"
echo "kubectl get secret backend-secrets -n $NAMESPACE -o yaml"
echo ""

echo -e "${GREEN}✓ Secret creation complete!${NC}"
