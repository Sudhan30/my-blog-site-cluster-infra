#!/bin/bash

# Blog Analytics Integration Setup Script
# This script helps you set up the complete analytics integration

echo "🚀 Setting up Blog Analytics Integration"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

print_info "Checking monitoring setup..."

# Check if monitoring is running in web namespace
echo ""
echo "📊 Checking Monitoring Components:"
echo "--------------------------------"

# Check Prometheus
if kubectl get pods -n web | grep -q prometheus; then
    PROMETHEUS_STATUS=$(kubectl get pods -n web | grep prometheus | awk '{print $3}')
    if [ "$PROMETHEUS_STATUS" = "Running" ]; then
        print_status "Prometheus is running"
    else
        print_warning "Prometheus pod exists but not running (Status: $PROMETHEUS_STATUS)"
    fi
else
    print_error "Prometheus pod not found in web namespace"
fi

# Check Grafana
if kubectl get pods -n web | grep -q grafana; then
    GRAFANA_STATUS=$(kubectl get pods -n web | grep grafana | awk '{print $3}')
    if [ "$GRAFANA_STATUS" = "Running" ]; then
        print_status "Grafana is running"
    else
        print_warning "Grafana pod exists but not running (Status: $GRAFANA_STATUS)"
    fi
else
    print_error "Grafana pod not found in web namespace"
fi

# Check services
echo ""
echo "🔗 Checking Services:"
echo "-------------------"
if kubectl get svc -n web | grep -q prometheus; then
    print_status "Prometheus service is configured"
else
    print_error "Prometheus service not found"
fi

if kubectl get svc -n web | grep -q grafana; then
    print_status "Grafana service is configured"
else
    print_error "Grafana service not found"
fi

# Check ingress
echo ""
echo "🌐 Checking Ingress:"
echo "------------------"
if kubectl get ingress -n web | grep -q monitoring; then
    print_status "Monitoring ingress is configured"
    
    # Show the URLs
    echo ""
    echo "📱 Access URLs:"
    echo "Grafana: https://grafana.sudharsana.dev"
    echo "Prometheus: https://prometheus.sudharsana.dev"
else
    print_error "Monitoring ingress not found"
fi

# Check backend metrics endpoint
echo ""
echo "📈 Checking Backend Metrics:"
echo "--------------------------"
if kubectl get pods -n web | grep -q blog-backend; then
    BACKEND_STATUS=$(kubectl get pods -n web | grep blog-backend | awk '{print $3}')
    if [ "$BACKEND_STATUS" = "Running" ]; then
        print_status "Blog backend is running"
        
        # Test metrics endpoint
        echo "Testing metrics endpoint..."
        if kubectl exec -n web $(kubectl get pods -n web -l app=blog-backend -o jsonpath='{.items[0].metadata.name}') -- curl -s http://localhost:3001/api/metrics | grep -q "http_requests_total"; then
            print_status "Backend metrics endpoint is working"
        else
            print_warning "Backend metrics endpoint might not be responding"
        fi
    else
        print_warning "Blog backend not running (Status: $BACKEND_STATUS)"
    fi
else
    print_error "Blog backend pod not found"
fi

echo ""
echo "🎯 Next Steps:"
echo "============="
echo ""
echo "1. 📊 Import Grafana Dashboard:"
echo "   - Go to https://grafana.sudharsana.dev"
echo "   - Login with admin/admin123 (or your configured credentials)"
echo "   - Go to '+' → Import"
echo "   - Upload the grafana-blog-analytics-dashboard.json file"
echo "   - Configure Prometheus as data source if not already done"
echo ""
echo "2. ⚙️  Update Prometheus Config:"
echo "   - Add the scraping jobs from prometheus-integration-config.yml"
echo "   - Update your prometheus-config ConfigMap in the web namespace"
echo "   - Restart Prometheus to pick up new configuration"
echo ""
echo "3. 🧪 Test Analytics Integration:"
echo "   - Deploy your frontend with analytics tracking"
echo "   - Check that metrics are flowing to Prometheus"
echo "   - Verify the Grafana dashboard shows data"
echo ""
echo "4. 🔍 Verify Metrics:"
echo "   - Check Prometheus targets: https://prometheus.sudharsana.dev/targets"
echo "   - View raw metrics: https://prometheus.sudharsana.dev/graph"
echo "   - Test queries like: page_views_total, clicks_total, user_sessions_total"
echo ""

# Quick test commands
echo "🔧 Quick Test Commands:"
echo "====================="
echo ""
echo "# Check all pods in web namespace:"
echo "kubectl get pods -n web"
echo ""
echo "# Check Prometheus targets:"
echo "kubectl port-forward -n web svc/prometheus-service 9090:9090"
echo "# Then visit: http://localhost:9090/targets"
echo ""
echo "# Check Grafana:"
echo "kubectl port-forward -n web svc/grafana-service 3000:3000"
echo "# Then visit: http://localhost:3000"
echo ""
echo "# Test backend metrics:"
echo "curl https://blog.sudharsana.dev/api/metrics | grep blog_"
echo ""

print_info "Analytics integration setup complete!"
print_info "Your comprehensive monitoring stack is ready! 📊✨"
