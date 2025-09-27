#!/bin/bash

# Deploy Monitoring Stack Script
# This script deploys and verifies your monitoring stack

echo "🚀 Deploying Monitoring Stack"
echo "============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

print_info "Deploying monitoring stack..."

# Deploy monitoring components
echo ""
echo "📦 Deploying Monitoring Components:"
echo "----------------------------------"

kubectl apply -k clusters/prod/apps/monitoring/

if [ $? -eq 0 ]; then
    print_status "Monitoring components deployed successfully"
else
    print_error "Failed to deploy monitoring components"
    exit 1
fi

echo ""
echo "⏳ Waiting for deployments to be ready..."
echo "----------------------------------------"

# Wait for Prometheus
print_info "Waiting for Prometheus deployment..."
kubectl rollout status deployment/prometheus -n web --timeout=300s

if [ $? -eq 0 ]; then
    print_status "Prometheus deployment is ready"
else
    print_warning "Prometheus deployment not ready within timeout"
fi

# Wait for Grafana
print_info "Waiting for Grafana deployment..."
kubectl rollout status deployment/grafana -n web --timeout=300s

if [ $? -eq 0 ]; then
    print_status "Grafana deployment is ready"
else
    print_warning "Grafana deployment not ready within timeout"
fi

echo ""
echo "🔍 Checking Pod Status:"
echo "---------------------"

kubectl get pods -n web -l 'app in (prometheus,grafana)' -o wide

echo ""
echo "🧪 Testing Internal Connectivity:"
echo "-------------------------------"

# Test Prometheus internal connectivity
PROMETHEUS_POD=$(kubectl get pods -n web -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
if [ -n "$PROMETHEUS_POD" ]; then
    print_info "Testing Prometheus internal API..."
    kubectl exec -n web $PROMETHEUS_POD -- wget -qO- http://localhost:9090/api/v1/query?query=up | head -c 100
    if [ $? -eq 0 ]; then
        print_status "Prometheus internal API is responding"
    else
        print_error "Prometheus internal API is not responding"
    fi
fi

# Test Grafana internal connectivity
GRAFANA_POD=$(kubectl get pods -n web -l app=grafana -o jsonpath='{.items[0].metadata.name}')
if [ -n "$GRAFANA_POD" ]; then
    print_info "Testing Grafana internal API..."
    kubectl exec -n web $GRAFANA_POD -- wget -qO- http://localhost:3000/api/health | head -c 50
    if [ $? -eq 0 ]; then
        print_status "Grafana internal API is responding"
    else
        print_error "Grafana internal API is not responding"
    fi
fi

echo ""
echo "🌐 Checking External Access:"
echo "---------------------------"

# Check ingress status
if kubectl get ingress monitoring-ingress -n web &> /dev/null; then
    print_status "Monitoring ingress is configured"
    
    # Test external access
    print_info "Testing external access to Prometheus..."
    curl -I -s --connect-timeout 10 https://prometheus.sudharsana.dev | head -1
    if [ $? -eq 0 ]; then
        print_status "External access to Prometheus is working"
    else
        print_warning "External access to Prometheus failed - check DNS and ingress"
    fi
    
    print_info "Testing external access to Grafana..."
    curl -I -s --connect-timeout 10 https://grafana.sudharsana.dev | head -1
    if [ $? -eq 0 ]; then
        print_status "External access to Grafana is working"
    else
        print_warning "External access to Grafana failed - check DNS and ingress"
    fi
else
    print_error "Monitoring ingress not found"
fi

echo ""
echo "📊 Prometheus Targets Status:"
echo "----------------------------"

# Check Prometheus targets
print_info "Checking Prometheus targets..."
kubectl exec -n web $PROMETHEUS_POD -- wget -qO- http://localhost:9090/api/v1/targets | grep -o '"health":"[^"]*"' | sort | uniq -c

echo ""
echo "🎯 Next Steps:"
echo "============="

echo ""
echo "1. 📊 Access Grafana Dashboard:"
echo "   https://grafana.sudharsana.dev"
echo "   Default credentials: admin/admin123"

echo ""
echo "2. 🔍 Access Prometheus UI:"
echo "   https://prometheus.sudharsana.dev"

echo ""
echo "3. 📈 Check Backend Metrics:"
echo "   https://blog.sudharsana.dev/api/metrics"

echo ""
echo "4. 🔧 If external access fails:"
echo "   kubectl port-forward -n web svc/prometheus-service 9090:9090"
echo "   kubectl port-forward -n web svc/grafana-service 3000:3000"

echo ""
echo "5. 📋 Import Grafana Dashboard:"
echo "   - Go to Grafana UI"
echo "   - Import grafana-blog-analytics-dashboard.json"
echo "   - Configure Prometheus as data source"

print_info "Monitoring stack deployment complete!"
print_info "Run ./setup-monitoring-stack.sh for detailed verification."
