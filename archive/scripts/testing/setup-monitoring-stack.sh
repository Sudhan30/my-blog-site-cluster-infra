#!/bin/bash

# Monitoring Stack Setup and Verification Script
# This script helps you set up and verify your Prometheus and Grafana deployment

echo "🔍 Monitoring Stack Setup and Verification"
echo "=========================================="

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
    print_info "Please run this script on your server where kubectl is available"
    exit 1
fi

print_info "Checking monitoring stack in web namespace..."

echo ""
echo "📊 Checking Prometheus:"
echo "---------------------"

# Check Prometheus deployment
if kubectl get deployment prometheus -n web &> /dev/null; then
    PROMETHEUS_STATUS=$(kubectl get deployment prometheus -n web -o jsonpath='{.status.readyReplicas}')
    PROMETHEUS_DESIRED=$(kubectl get deployment prometheus -n web -o jsonpath='{.spec.replicas}')
    
    if [ "$PROMETHEUS_STATUS" = "$PROMETHEUS_DESIRED" ]; then
        print_status "Prometheus deployment is running ($PROMETHEUS_STATUS/$PROMETHEUS_DESIRED)"
    else
        print_warning "Prometheus deployment not ready ($PROMETHEUS_STATUS/$PROMETHEUS_DESIRED)"
    fi
else
    print_error "Prometheus deployment not found in web namespace"
    echo "Run: kubectl apply -k clusters/prod/apps/monitoring/"
fi

# Check Prometheus service
if kubectl get service prometheus-service -n web &> /dev/null; then
    print_status "Prometheus service is configured"
    kubectl get service prometheus-service -n web
else
    print_error "Prometheus service not found"
fi

# Check Prometheus pods
echo ""
echo "🔍 Prometheus Pod Status:"
kubectl get pods -n web -l app=prometheus -o wide

echo ""
echo "📊 Checking Grafana:"
echo "------------------"

# Check Grafana deployment
if kubectl get deployment grafana -n web &> /dev/null; then
    GRAFANA_STATUS=$(kubectl get deployment grafana -n web -o jsonpath='{.status.readyReplicas}')
    GRAFANA_DESIRED=$(kubectl get deployment grafana -n web -o jsonpath='{.spec.replicas}')
    
    if [ "$GRAFANA_STATUS" = "$GRAFANA_DESIRED" ]; then
        print_status "Grafana deployment is running ($GRAFANA_STATUS/$GRAFANA_DESIRED)"
    else
        print_warning "Grafana deployment not ready ($GRAFANA_STATUS/$GRAFANA_DESIRED)"
    fi
else
    print_error "Grafana deployment not found in web namespace"
fi

# Check Grafana service
if kubectl get service grafana-service -n web &> /dev/null; then
    print_status "Grafana service is configured"
    kubectl get service grafana-service -n web
else
    print_error "Grafana service not found"
fi

# Check Grafana pods
echo ""
echo "🔍 Grafana Pod Status:"
kubectl get pods -n web -l app=grafana -o wide

echo ""
echo "🌐 Checking Ingress:"
echo "------------------"

# Check monitoring ingress
if kubectl get ingress monitoring-ingress -n web &> /dev/null; then
    print_status "Monitoring ingress is configured"
    kubectl get ingress monitoring-ingress -n web
    
    # Check ingress status
    INGRESS_STATUS=$(kubectl get ingress monitoring-ingress -n web -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$INGRESS_STATUS" ]; then
        print_status "Ingress is ready: $INGRESS_STATUS"
    else
        print_warning "Ingress not ready yet"
    fi
else
    print_error "Monitoring ingress not found"
fi

echo ""
echo "🔐 Checking Authentication Middleware:"
echo "------------------------------------"

# Check if auth middleware exists
if kubectl get middleware web-auth -n kubernetescrd &> /dev/null; then
    print_status "Authentication middleware is configured"
else
    print_warning "Authentication middleware 'web-auth' not found"
    print_info "This might be why prometheus.sudharsana.dev is not accessible"
fi

echo ""
echo "🧪 Testing Internal Connectivity:"
echo "-------------------------------"

# Test internal service connectivity
if kubectl get pods -n web -l app=prometheus | grep -q Running; then
    print_info "Testing Prometheus internal connectivity..."
    kubectl exec -n web $(kubectl get pods -n web -l app=prometheus -o jsonpath='{.items[0].metadata.name}') -- wget -qO- http://localhost:9090/api/v1/query?query=up | head -c 100
    if [ $? -eq 0 ]; then
        print_status "Prometheus internal API is responding"
    else
        print_error "Prometheus internal API is not responding"
    fi
fi

if kubectl get pods -n web -l app=grafana | grep -q Running; then
    print_info "Testing Grafana internal connectivity..."
    kubectl exec -n web $(kubectl get pods -n web -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- wget -qO- http://localhost:3000/api/health | head -c 50
    if [ $? -eq 0 ]; then
        print_status "Grafana internal API is responding"
    else
        print_error "Grafana internal API is not responding"
    fi
fi

echo ""
echo "📋 Configuration Summary:"
echo "========================"

echo ""
echo "🏠 Internal Service URLs:"
echo "- Prometheus: http://prometheus-service.web.svc.cluster.local:9090"
echo "- Grafana: http://grafana-service.web.svc.cluster.local:3000"

echo ""
echo "🌐 External URLs (if ingress is working):"
echo "- Prometheus: https://prometheus.sudharsana.dev"
echo "- Grafana: https://grafana.sudharsana.dev"

echo ""
echo "🔧 Troubleshooting Commands:"
echo "==========================="

echo ""
echo "1. Deploy/Update Monitoring Stack:"
echo "   kubectl apply -k clusters/prod/apps/monitoring/"

echo ""
echo "2. Check Pod Logs:"
echo "   kubectl logs -n web -l app=prometheus --tail=50"
echo "   kubectl logs -n web -l app=grafana --tail=50"

echo ""
echo "3. Port Forward for Testing:"
echo "   kubectl port-forward -n web svc/prometheus-service 9090:9090"
echo "   kubectl port-forward -n web svc/grafana-service 3000:3000"

echo ""
echo "4. Check Ingress Status:"
echo "   kubectl describe ingress monitoring-ingress -n web"

echo ""
echo "5. Check Authentication Middleware:"
echo "   kubectl get middleware -A"

echo ""
echo "6. Test DNS Resolution:"
echo "   nslookup prometheus.sudharsana.dev"
echo "   nslookup grafana.sudharsana.dev"

echo ""
echo "🎯 Next Steps:"
echo "============="

echo ""
echo "1. 📊 Deploy Monitoring Stack:"
echo "   kubectl apply -k clusters/prod/apps/monitoring/"

echo ""
echo "2. 🔍 Wait for Pods to be Ready:"
echo "   kubectl get pods -n web -w"

echo ""
echo "3. 🌐 Check Ingress Configuration:"
echo "   kubectl get ingress -n web"

echo ""
echo "4. 🔐 Verify Authentication Middleware:"
echo "   kubectl get middleware -A | grep web-auth"

echo ""
echo "5. 🧪 Test Access:"
echo "   curl -I https://prometheus.sudharsana.dev"
echo "   curl -I https://grafana.sudharsana.dev"

print_info "Monitoring stack verification complete!"
print_info "Run the troubleshooting commands above if you encounter issues."
