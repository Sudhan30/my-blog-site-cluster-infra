#!/bin/bash

# Quick Deployment Test Script
# This script provides a quick way to test if components are deployed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="web"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

highlight() {
    echo -e "${CYAN}[HIGHLIGHT]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "kubectl not connected to cluster. Please configure kubectl."
        exit 1
    fi
    
    success "kubectl is available and connected"
}

# Function to check if components are deployed
check_deployment() {
    log "Checking if components are deployed..."
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        error "Namespace '$NAMESPACE' does not exist"
        echo "Run: kubectl create namespace $NAMESPACE"
        return 1
    fi
    success "Namespace '$NAMESPACE' exists"
    
    # Check deployments
    local deployments=("blog" "blog-backend" "postgres" "prometheus" "grafana")
    local deployed_count=0
    
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
            local ready=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            
            if [ "$ready" = "$desired" ] && [ "$ready" != "0" ]; then
                success "$deployment: deployed and ready ($ready/$desired)"
                deployed_count=$((deployed_count + 1))
            else
                warning "$deployment: deployed but not ready ($ready/$desired)"
            fi
        else
            error "$deployment: not deployed"
        fi
    done
    
    echo ""
    highlight "Deployment Status: $deployed_count/${#deployments[@]} components ready"
    
    if [ "$deployed_count" -eq "${#deployments[@]}" ]; then
        success "All components are deployed and ready! 🎉"
        return 0
    else
        warning "Some components are not ready yet"
        return 1
    fi
}

# Function to show quick status
show_quick_status() {
    log "Showing quick deployment status..."
    
    echo ""
    highlight "=== PODS STATUS ==="
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "No pods found"
    
    echo ""
    highlight "=== SERVICES STATUS ==="
    kubectl get svc -n "$NAMESPACE" 2>/dev/null || echo "No services found"
    
    echo ""
    highlight "=== INGRESS STATUS ==="
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "No ingress found"
}

# Function to test basic connectivity
test_connectivity() {
    log "Testing basic connectivity..."
    
    local endpoints=(
        "https://blog.sudharsana.dev"
        "https://api.sudharsana.dev/health"
        "https://grafana.sudharsana.dev"
        "https://prometheus.sudharsana.dev"
    )
    
    local accessible_count=0
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f --max-time 5 "$endpoint" > /dev/null 2>&1; then
            success "$endpoint - accessible"
            accessible_count=$((accessible_count + 1))
        else
            error "$endpoint - not accessible"
        fi
    done
    
    echo ""
    highlight "Connectivity Status: $accessible_count/${#endpoints[@]} endpoints accessible"
    
    if [ "$accessible_count" -eq "${#endpoints[@]}" ]; then
        success "All endpoints are accessible! 🎉"
        return 0
    else
        warning "Some endpoints are not accessible"
        return 1
    fi
}

# Function to show deployment commands
show_deployment_commands() {
    highlight "=== DEPLOYMENT COMMANDS ==="
    echo ""
    echo "To deploy the backend stack:"
    echo "  ./setup-backend-stack.sh setup"
    echo ""
    echo "To check deployment status:"
    echo "  ./check-deployment-status.sh check"
    echo ""
    echo "To test the API:"
    echo "  ./test-backend-api.sh test"
    echo ""
    echo "Manual deployment:"
    echo "  kubectl apply -k clusters/prod/"
    echo ""
    echo "Check specific component:"
    echo "  kubectl get pods -n $NAMESPACE -l app=blog-backend"
    echo "  kubectl get pods -n $NAMESPACE -l app=postgres"
    echo "  kubectl get pods -n $NAMESPACE -l app=prometheus"
    echo "  kubectl get pods -n $NAMESPACE -l app=grafana"
}

# Function to show help
show_help() {
    echo "Quick Deployment Test Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  check                    - Check if components are deployed"
    echo "  status                   - Show quick status"
    echo "  test                     - Test basic connectivity"
    echo "  commands                 - Show deployment commands"
    echo "  help                     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 check                 # Check deployment status"
    echo "  $0 status                # Show quick status"
    echo "  $0 test                  # Test connectivity"
    echo "  $0 commands              # Show deployment commands"
}

# Main script logic
case "${1:-}" in
    "check")
        check_kubectl
        check_deployment
        ;;
    "status")
        check_kubectl
        show_quick_status
        ;;
    "test")
        test_connectivity
        ;;
    "commands")
        show_deployment_commands
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Quick Deployment Test Script"
        echo ""
        echo "Usage: $0 [command]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 check              # Check if components are deployed"
        echo "  $0 status             # Show quick status"
        echo "  $0 test               # Test connectivity"
        echo "  $0 commands           # Show deployment commands"
        echo "  $0 help               # Show detailed help"
        ;;
esac
