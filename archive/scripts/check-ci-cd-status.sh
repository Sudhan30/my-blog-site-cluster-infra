#!/bin/bash

# CI/CD Status Checker
# This script checks the status of your CI/CD pipeline and deployments

set -e

echo "🚀 CI/CD Pipeline Status Checker"
echo "================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success") echo -e "${GREEN}✅ $message${NC}" ;;
        "warning") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "error") echo -e "${RED}❌ $message${NC}" ;;
        "info") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_status "error" "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if flux is available
if ! command -v flux &> /dev/null; then
    print_status "warning" "flux CLI not found. Install it for better monitoring."
fi

echo "📋 Checking Flux CD Status..."
echo "----------------------------"

# Check Flux system status
if kubectl get pods -n flux-system &> /dev/null; then
    print_status "info" "Flux system pods:"
    kubectl get pods -n flux-system
    echo ""
else
    print_status "error" "Cannot access flux-system namespace"
    exit 1
fi

# Check GitRepository status
echo "🔗 Checking GitRepository status..."
if kubectl get gitrepository -n flux-system &> /dev/null; then
    kubectl get gitrepository -n flux-system
    echo ""
else
    print_status "warning" "No GitRepository found in flux-system"
fi

# Check Kustomization status
echo "📦 Checking Kustomization status..."
if kubectl get kustomization -n flux-system &> /dev/null; then
    kubectl get kustomization -n flux-system
    echo ""
else
    print_status "warning" "No Kustomization found in flux-system"
fi

# Check ImageRepository status
echo "🐳 Checking ImageRepository status..."
if kubectl get imagerepository -n flux-system &> /dev/null; then
    kubectl get imagerepository -n flux-system
    echo ""
else
    print_status "warning" "No ImageRepository found in flux-system"
fi

# Check ImagePolicy status
echo "📋 Checking ImagePolicy status..."
if kubectl get imagepolicy -n flux-system &> /dev/null; then
    kubectl get imagepolicy -n flux-system
    echo ""
else
    print_status "warning" "No ImagePolicy found in flux-system"
fi

# Check ImageUpdateAutomation status
echo "🔄 Checking ImageUpdateAutomation status..."
if kubectl get imageupdateautomation -n flux-system &> /dev/null; then
    kubectl get imageupdateautomation -n flux-system
    echo ""
else
    print_status "warning" "No ImageUpdateAutomation found in flux-system"
fi

# Check application pods
echo "🚀 Checking Application Pods..."
echo "-------------------------------"

if kubectl get pods -n web &> /dev/null; then
    print_status "info" "Blog application pods:"
    kubectl get pods -n web
    echo ""
    
    print_status "info" "Pod details:"
    kubectl describe pods -n web
    echo ""
else
    print_status "warning" "No pods found in web namespace"
fi

# Check services
echo "🌐 Checking Services..."
echo "----------------------"

if kubectl get services -n web &> /dev/null; then
    kubectl get services -n web
    echo ""
else
    print_status "warning" "No services found in web namespace"
fi

# Check deployments
echo "📦 Checking Deployments..."
echo "--------------------------"

if kubectl get deployments -n web &> /dev/null; then
    kubectl get deployments -n web
    echo ""
else
    print_status "warning" "No deployments found in web namespace"
fi

# Check HPA
echo "📊 Checking HPA..."
echo "------------------"

if kubectl get hpa -n web &> /dev/null; then
    kubectl get hpa -n web
    echo ""
else
    print_status "warning" "No HPA found in web namespace"
fi

# Check recent events
echo "📅 Recent Events..."
echo "------------------"

kubectl get events -n web --sort-by='.lastTimestamp' | tail -10
echo ""

# Check image tags
echo "🏷️  Current Image Tags..."
echo "------------------------"

echo "Blog deployment image:"
kubectl get deployment blog -n web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "Not found"
echo ""

echo "Backend deployment image:"
kubectl get deployment blog-backend -n web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "Not found"
echo ""

# Test endpoints
echo "🔍 Testing Endpoints..."
echo "----------------------"

# Test blog health endpoint
print_status "info" "Testing blog health endpoint..."
if kubectl run test-blog-health --image=curlimages/curl --rm -i --restart=Never --timeout=10s -- \
   curl -f http://blog-service:80/health &> /dev/null; then
    print_status "success" "Blog health endpoint is responding"
else
    print_status "warning" "Blog health endpoint test failed"
fi

# Test backend health endpoint
print_status "info" "Testing backend health endpoint..."
if kubectl run test-backend-health --image=curlimages/curl --rm -i --restart=Never --timeout=10s -- \
   curl -f http://blog-backend-service:3001/health &> /dev/null; then
    print_status "success" "Backend health endpoint is responding"
else
    print_status "warning" "Backend health endpoint test failed"
fi

echo ""
echo "🎯 Summary"
echo "=========="
echo "Run this script regularly to monitor your CI/CD pipeline status."
echo "For detailed logs, check: kubectl logs -n flux-system -l app=flux"
echo ""
echo "🌐 Your blog should be available at: https://blog.sudharsana.dev"
echo "📊 Backend API should be available at: https://api.sudharsana.dev"
echo "📈 Grafana should be available at: https://grafana.sudharsana.dev"
echo ""
