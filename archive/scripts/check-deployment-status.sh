#!/bin/bash

# Deployment Status Check Script
# This script checks if all components are deployed and running

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="web"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${PURPLE}[INFO]${NC} $1"
}

highlight() {
    echo -e "${CYAN}[HIGHLIGHT]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        echo "Please install kubectl first:"
        echo "  curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        echo "  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "kubectl is not connected to a cluster"
        echo "Please configure kubectl to connect to your cluster"
        return 1
    fi
    
    success "kubectl is available and connected"
    return 0
}

# Function to check namespace
check_namespace() {
    log "Checking namespace '$NAMESPACE'..."
    
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        success "Namespace '$NAMESPACE' exists"
        return 0
    else
        error "Namespace '$NAMESPACE' does not exist"
        echo "Creating namespace..."
        kubectl create namespace "$NAMESPACE"
        success "Namespace '$NAMESPACE' created"
        return 1
    fi
}

# Function to check deployments
check_deployments() {
    log "Checking deployments..."
    
    local deployments=(
        "blog"
        "blog-backend"
        "postgres"
        "prometheus"
        "grafana"
        "postgres-exporter"
        "blackbox-exporter"
    )
    
    local all_ready=true
    
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
            local ready_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            
            if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
                success "$deployment: $ready_replicas/$desired_replicas ready"
            else
                warning "$deployment: $ready_replicas/$desired_replicas ready"
                all_ready=false
            fi
        else
            error "$deployment: deployment not found"
            all_ready=false
        fi
    done
    
    return $([ "$all_ready" = true ] && echo 0 || echo 1)
}

# Function to check pods
check_pods() {
    log "Checking pods..."
    
    local pods=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pods" ]; then
        error "No pods found in namespace '$NAMESPACE'"
        return 1
    fi
    
    local total_pods=$(echo "$pods" | wc -l)
    local running_pods=$(echo "$pods" | grep "Running" | wc -l)
    local pending_pods=$(echo "$pods" | grep "Pending" | wc -l)
    local failed_pods=$(echo "$pods" | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l)
    
    echo "Total pods: $total_pods"
    echo "Running: $running_pods"
    echo "Pending: $pending_pods"
    echo "Failed: $failed_pods"
    
    if [ "$failed_pods" -gt 0 ]; then
        error "Some pods are in failed state:"
        echo "$pods" | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)"
        return 1
    fi
    
    if [ "$running_pods" -eq "$total_pods" ]; then
        success "All pods are running"
        return 0
    else
        warning "Not all pods are running yet"
        return 1
    fi
}

# Function to check services
check_services() {
    log "Checking services..."
    
    local services=$(kubectl get svc -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$services" ]; then
        error "No services found in namespace '$NAMESPACE'"
        return 1
    fi
    
    local service_count=$(echo "$services" | wc -l)
    success "Found $service_count services"
    
    echo ""
    info "Services:"
    kubectl get svc -n "$NAMESPACE"
    
    return 0
}

# Function to check ingress
check_ingress() {
    log "Checking ingress..."
    
    local ingress=$(kubectl get ingress -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$ingress" ]; then
        warning "No ingress found in namespace '$NAMESPACE'"
        return 1
    fi
    
    local ingress_count=$(echo "$ingress" | wc -l)
    success "Found $ingress_count ingress resources"
    
    echo ""
    info "Ingress:"
    kubectl get ingress -n "$NAMESPACE"
    
    return 0
}

# Function to check persistent volumes
check_pvcs() {
    log "Checking persistent volume claims..."
    
    local pvcs=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pvcs" ]; then
        warning "No PVCs found in namespace '$NAMESPACE'"
        return 1
    fi
    
    local bound_pvcs=$(echo "$pvcs" | grep "Bound" | wc -l)
    local total_pvcs=$(echo "$pvcs" | wc -l)
    
    if [ "$bound_pvcs" -eq "$total_pvcs" ]; then
        success "All PVCs are bound ($bound_pvcs/$total_pvcs)"
    else
        warning "Some PVCs are not bound ($bound_pvcs/$total_pvcs)"
    fi
    
    echo ""
    info "PVCs:"
    kubectl get pvc -n "$NAMESPACE"
    
    return 0
}

# Function to check Flux sync status
check_flux_sync() {
    log "Checking Flux sync status..."
    
    if ! command -v flux &> /dev/null; then
        warning "Flux CLI not found - skipping Flux sync check"
        return 0
    fi
    
    local kustomizations=$(flux get kustomizations -n flux-system --no-headers 2>/dev/null || echo "")
    
    if [ -z "$kustomizations" ]; then
        warning "No Flux kustomizations found"
        return 1
    fi
    
    local synced_count=$(echo "$kustomizations" | grep "True" | wc -l)
    local total_count=$(echo "$kustomizations" | wc -l)
    
    if [ "$synced_count" -eq "$total_count" ]; then
        success "All Flux kustomizations are synced ($synced_count/$total_count)"
    else
        warning "Some Flux kustomizations are not synced ($synced_count/$total_count)"
    fi
    
    echo ""
    info "Flux Kustomizations:"
    flux get kustomizations -n flux-system
    
    return 0
}

# Function to test API endpoints
test_api_endpoints() {
    log "Testing API endpoints..."
    
    local endpoints=(
        "https://blog.sudharsana.dev"
        "https://api.sudharsana.dev/health"
        "https://grafana.sudharsana.dev"
        "https://prometheus.sudharsana.dev"
    )
    
    local all_working=true
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f --max-time 10 "$endpoint" > /dev/null 2>&1; then
            success "$endpoint - accessible"
        else
            error "$endpoint - not accessible"
            all_working=false
        fi
    done
    
    return $([ "$all_working" = true ] && echo 0 || echo 1)
}

# Function to show detailed status
show_detailed_status() {
    log "Showing detailed deployment status..."
    
    echo ""
    highlight "=== PODS STATUS ==="
    kubectl get pods -n "$NAMESPACE" -o wide
    
    echo ""
    highlight "=== DEPLOYMENTS STATUS ==="
    kubectl get deployments -n "$NAMESPACE" -o wide
    
    echo ""
    highlight "=== SERVICES STATUS ==="
    kubectl get svc -n "$NAMESPACE" -o wide
    
    echo ""
    highlight "=== INGRESS STATUS ==="
    kubectl get ingress -n "$NAMESPACE" -o wide
    
    echo ""
    highlight "=== PVCs STATUS ==="
    kubectl get pvc -n "$NAMESPACE" -o wide
    
    echo ""
    highlight "=== EVENTS ==="
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
}

# Function to check specific component
check_component() {
    local component="$1"
    
    case "$component" in
        "backend")
            log "Checking backend component..."
            kubectl get pods -n "$NAMESPACE" -l app=blog-backend
            kubectl get svc -n "$NAMESPACE" -l app=blog-backend
            ;;
        "blog")
            log "Checking blog component..."
            kubectl get pods -n "$NAMESPACE" -l app=blog
            kubectl get svc -n "$NAMESPACE" -l app=blog
            ;;
        "postgres")
            log "Checking PostgreSQL component..."
            kubectl get pods -n "$NAMESPACE" -l app=postgres
            kubectl get svc -n "$NAMESPACE" -l app=postgres
            ;;
        "prometheus")
            log "Checking Prometheus component..."
            kubectl get pods -n "$NAMESPACE" -l app=prometheus
            kubectl get svc -n "$NAMESPACE" -l app=prometheus
            ;;
        "grafana")
            log "Checking Grafana component..."
            kubectl get pods -n "$NAMESPACE" -l app=grafana
            kubectl get svc -n "$NAMESPACE" -l app=grafana
            ;;
        "monitoring")
            log "Checking monitoring components..."
            kubectl get pods -n "$NAMESPACE" -l app=prometheus
            kubectl get pods -n "$NAMESPACE" -l app=grafana
            kubectl get pods -n "$NAMESPACE" -l app=postgres-exporter
            kubectl get pods -n "$NAMESPACE" -l app=blackbox-exporter
            ;;
        *)
            error "Unknown component: $component"
            echo "Available components: backend, blog, postgres, prometheus, grafana, monitoring"
            return 1
            ;;
    esac
}

# Function to run complete status check
run_complete_check() {
    log "Running complete deployment status check..."
    echo ""
    
    local results=()
    
    # Run checks
    check_kubectl && results+=("kubectl: PASS") || results+=("kubectl: FAIL")
    check_namespace && results+=("namespace: PASS") || results+=("namespace: FAIL")
    check_deployments && results+=("deployments: PASS") || results+=("deployments: FAIL")
    check_pods && results+=("pods: PASS") || results+=("pods: FAIL")
    check_services && results+=("services: PASS") || results+=("services: FAIL")
    check_ingress && results+=("ingress: PASS") || results+=("ingress: FAIL")
    check_pvcs && results+=("pvcs: PASS") || results+=("pvcs: FAIL")
    check_flux_sync && results+=("flux: PASS") || results+=("flux: FAIL")
    test_api_endpoints && results+=("endpoints: PASS") || results+=("endpoints: FAIL")
    
    # Show results
    echo ""
    highlight "=== CHECK RESULTS ==="
    for result in "${results[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            success "$result"
        else
            error "$result"
        fi
    done
    
    # Count results
    local pass_count=$(echo "${results[@]}" | grep -o "PASS" | wc -l)
    local fail_count=$(echo "${results[@]}" | grep -o "FAIL" | wc -l)
    
    echo ""
    highlight "=== SUMMARY ==="
    echo "Total checks: $((pass_count + fail_count))"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    
    if [ "$fail_count" -eq 0 ]; then
        success "All checks passed! Deployment is healthy! 🎉"
        return 0
    else
        warning "Some checks failed. See details above."
        return 1
    fi
}

# Function to show help
show_help() {
    echo "Deployment Status Check Script"
    echo ""
    echo "Usage: $0 [command] [component]"
    echo ""
    echo "Commands:"
    echo "  check                    - Run complete deployment check"
    echo "  deployments             - Check deployments only"
    echo "  pods                    - Check pods only"
    echo "  services                - Check services only"
    echo "  ingress                 - Check ingress only"
    echo "  pvcs                    - Check PVCs only"
    echo "  flux                    - Check Flux sync status"
    echo "  endpoints               - Test API endpoints"
    echo "  component <name>        - Check specific component"
    echo "  detailed                - Show detailed status"
    echo "  help                    - Show this help message"
    echo ""
    echo "Components:"
    echo "  backend                 - Blog backend API"
    echo "  blog                    - Blog frontend"
    echo "  postgres                - PostgreSQL database"
    echo "  prometheus              - Prometheus monitoring"
    echo "  grafana                 - Grafana dashboards"
    echo "  monitoring              - All monitoring components"
    echo ""
    echo "Examples:"
    echo "  $0 check                # Run complete check"
    echo "  $0 deployments          # Check deployments only"
    echo "  $0 component backend    # Check backend component"
    echo "  $0 detailed             # Show detailed status"
    echo ""
}

# Main script logic
case "${1:-}" in
    "check")
        run_complete_check
        ;;
    "deployments")
        check_deployments
        ;;
    "pods")
        check_pods
        ;;
    "services")
        check_services
        ;;
    "ingress")
        check_ingress
        ;;
    "pvcs")
        check_pvcs
        ;;
    "flux")
        check_flux_sync
        ;;
    "endpoints")
        test_api_endpoints
        ;;
    "component")
        check_component "$2"
        ;;
    "detailed")
        show_detailed_status
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Deployment Status Check Script"
        echo ""
        echo "Usage: $0 [command] [component]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 check              # Run complete deployment check"
        echo "  $0 deployments        # Check deployments only"
        echo "  $0 pods               # Check pods only"
        echo "  $0 detailed           # Show detailed status"
        echo "  $0 help               # Show detailed help"
        ;;
esac
