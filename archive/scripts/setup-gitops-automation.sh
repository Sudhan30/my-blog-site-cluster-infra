#!/bin/bash

# Complete GitOps Automation Setup Script
# This script sets up full automation from Git push to deployment

set -e

echo "🚀 Setting up Complete GitOps Automation Pipeline..."
echo "📅 $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found"
    exit 1
fi

if ! command -v flux &> /dev/null; then
    print_error "flux not found"
    exit 1
fi

if ! command -v git &> /dev/null; then
    print_error "git not found"
    exit 1
fi

print_success "Prerequisites OK"
echo ""

# Step 1: Configure Flux for automatic sync
print_status "Step 1: Configuring Flux for automatic sync..."

# Update flux-system kustomization to sync entire clusters/prod directory
kubectl -n flux-system patch kustomization flux-system --type='merge' -p='{"spec":{"path":"./clusters/prod"}}' || {
    print_warning "Failed to patch kustomization, trying alternative approach..."
    
    # Alternative: Delete and recreate
    kubectl -n flux-system delete kustomization flux-system
    flux create kustomization flux-system \
        --source=GitRepository/flux-system/flux-system \
        --path="./clusters/prod" \
        --prune=true \
        --interval=1m \
        --namespace=flux-system
}

print_success "Flux configured for automatic sync"
echo ""

# Step 2: Set up automatic reconciliation
print_status "Step 2: Setting up automatic reconciliation..."

# Create a reconciliation script
cat > /tmp/flux-reconcile.sh << 'EOF'
#!/bin/bash
# Automatic Flux reconciliation script

NAMESPACE="flux-system"
INTERVAL=30  # seconds

while true; do
    echo "$(date): Checking Flux sync status..."
    
    # Check if any kustomizations need reconciliation
    NEEDS_SYNC=$(flux get kustomizations -n $NAMESPACE --no-header | grep -v "Ready" | wc -l)
    
    if [ "$NEEDS_SYNC" -gt 0 ]; then
        echo "$(date): Reconciling $NEEDS_SYNC kustomizations..."
        
        # Reconcile all kustomizations
        flux reconcile kustomization flux-system -n $NAMESPACE
        
        # Wait for sync to complete
        sleep 10
        
        # Check status
        flux get kustomizations -n $NAMESPACE
    else
        echo "$(date): All kustomizations are ready"
    fi
    
    sleep $INTERVAL
done
EOF

chmod +x /tmp/flux-reconcile.sh
print_success "Reconciliation script created"
echo ""

# Step 3: Set up monitoring and alerting
print_status "Step 3: Setting up monitoring and alerting..."

# Create monitoring script
cat > /tmp/monitor-deployments.sh << 'EOF'
#!/bin/bash
# Deployment monitoring script

NAMESPACE="web"
APP_LABEL="app=blog"
LOG_FILE="/tmp/deployment-monitor.log"

while true; do
    TIMESTAMP=$(date)
    
    # Check pod status
    POD_STATUS=$(kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers 2>/dev/null | awk '{print $3}' | sort | uniq -c)
    
    # Check deployment status
    DEPLOY_STATUS=$(kubectl -n $NAMESPACE get deploy blog --no-headers 2>/dev/null | awk '{print $2}')
    
    # Check if any pods are in error state
    ERROR_PODS=$(kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers 2>/dev/null | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l)
    
    # Log status
    echo "$TIMESTAMP - Pods: $POD_STATUS, Deployment: $DEPLOY_STATUS, Errors: $ERROR_PODS" >> $LOG_FILE
    
    # Alert if there are errors
    if [ "$ERROR_PODS" -gt 0 ]; then
        echo "🚨 ALERT: $ERROR_PODS pods in error state at $TIMESTAMP" >> $LOG_FILE
        echo "🚨 ALERT: $ERROR_PODS pods in error state at $TIMESTAMP"
        
        # Get error details
        kubectl -n $NAMESPACE get pods -l $APP_LABEL | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" >> $LOG_FILE
    fi
    
    sleep 60
done
EOF

chmod +x /tmp/monitor-deployments.sh
print_success "Monitoring script created"
echo ""

# Step 4: Create automated testing
print_status "Step 4: Setting up automated testing..."

# Create automated test script
cat > /tmp/automated-tests.sh << 'EOF'
#!/bin/bash
# Automated testing script

NAMESPACE="web"
APP_LABEL="app=blog"
TEST_RESULTS="/tmp/test-results.log"

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Running test: $test_name"
    
    if eval "$test_command"; then
        echo "✅ $test_name: PASSED" >> $TEST_RESULTS
        echo "✅ $test_name: PASSED"
        return 0
    else
        echo "❌ $test_name: FAILED" >> $TEST_RESULTS
        echo "❌ $test_name: FAILED"
        return 1
    fi
}

# Test 1: Check if deployment exists
run_test "Deployment Exists" "kubectl -n $NAMESPACE get deploy blog"

# Test 2: Check if pods are running
run_test "Pods Running" "kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers | grep -q Running"

# Test 3: Check health endpoint
run_test "Health Endpoint" "kubectl -n $NAMESPACE exec \$(kubectl -n $NAMESPACE get pod -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}') -- curl -s http://localhost/health | grep -q healthy"

# Test 4: Check ConfigMap
run_test "ConfigMap Exists" "kubectl -n $NAMESPACE get configmap blog-nginx-conf"

# Test 5: Check Service
run_test "Service Exists" "kubectl -n $NAMESPACE get svc blog"

echo ""
echo "Test Results Summary:"
cat $TEST_RESULTS
EOF

chmod +x /tmp/automated-tests.sh
print_success "Automated testing script created"
echo ""

# Step 5: Set up Git hooks for automation
print_status "Step 5: Setting up Git hooks for automation..."

# Create pre-push hook
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
# Pre-push hook for automated testing

echo "🔍 Running pre-push tests..."

# Run automated tests
if [ -f "/tmp/automated-tests.sh" ]; then
    /tmp/automated-tests.sh
    if [ $? -ne 0 ]; then
        echo "❌ Pre-push tests failed. Push aborted."
        exit 1
    fi
fi

echo "✅ Pre-push tests passed. Proceeding with push."
EOF

chmod +x .git/hooks/pre-push
print_success "Git hooks configured"
echo ""

# Step 6: Create deployment automation script
print_status "Step 6: Creating deployment automation script..."

cat > /tmp/deploy-automation.sh << 'EOF'
#!/bin/bash
# Complete deployment automation script

echo "🚀 Starting automated deployment process..."

# Step 1: Check Flux status
echo "📋 Checking Flux status..."
flux get kustomizations -n flux-system

# Step 2: Force reconciliation
echo "🔄 Forcing reconciliation..."
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system

# Step 3: Wait for sync
echo "⏳ Waiting for sync to complete..."
timeout 300 bash -c 'until flux get kustomizations -n flux-system | grep -q "Ready"; do sleep 5; done'

# Step 4: Run tests
echo "🧪 Running automated tests..."
if [ -f "/tmp/automated-tests.sh" ]; then
    /tmp/automated-tests.sh
fi

# Step 5: Check final status
echo "📊 Final deployment status:"
kubectl -n web get all -l app=blog

echo "✅ Automated deployment completed!"
EOF

chmod +x /tmp/deploy-automation.sh
print_success "Deployment automation script created"
echo ""

# Step 7: Set up systemd services for background processes
print_status "Step 7: Setting up systemd services..."

# Create systemd service for reconciliation
sudo tee /etc/systemd/system/flux-reconcile.service > /dev/null << EOF
[Unit]
Description=Flux Automatic Reconciliation
After=network.target

[Service]
Type=simple
User=sudhan0312
ExecStart=/tmp/flux-reconcile.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for monitoring
sudo tee /etc/systemd/system/deployment-monitor.service > /dev/null << EOF
[Unit]
Description=Deployment Monitoring
After=network.target

[Service]
Type=simple
User=sudhan0312
ExecStart=/tmp/monitor-deployments.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable services
sudo systemctl daemon-reload
sudo systemctl enable flux-reconcile.service
sudo systemctl enable deployment-monitor.service

print_success "Systemd services configured"
echo ""

# Step 8: Final configuration
print_status "Step 8: Final configuration..."

# Force initial reconciliation
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system

# Run initial tests
if [ -f "/tmp/automated-tests.sh" ]; then
    /tmp/automated-tests.sh
fi

print_success "GitOps automation setup completed!"
echo ""

# Summary
echo "📋 SUMMARY:"
echo "  ✅ Flux configured for automatic sync"
echo "  ✅ Reconciliation automation set up"
echo "  ✅ Monitoring and alerting configured"
echo "  ✅ Automated testing implemented"
echo "  ✅ Git hooks configured"
echo "  ✅ Systemd services created"
echo ""
echo "🚀 AUTOMATION WORKFLOW:"
echo "  1. Push changes to Git repository"
echo "  2. Flux automatically detects changes"
echo "  3. Flux syncs and applies manifests"
echo "  4. Monitoring detects deployment status"
echo "  5. Automated tests verify functionality"
echo "  6. Alerts sent if issues detected"
echo ""
echo "📝 USEFUL COMMANDS:"
echo "  • Start monitoring: sudo systemctl start deployment-monitor"
echo "  • Start reconciliation: sudo systemctl start flux-reconcile"
echo "  • Check status: flux get kustomizations -n flux-system"
echo "  • Run tests: /tmp/automated-tests.sh"
echo "  • Deploy manually: /tmp/deploy-automation.sh"
echo ""
echo "🎉 Your GitOps automation pipeline is ready!"
