#!/bin/bash

# HorizontalPodAutoscaler Management Script
# This script manages HPA for the blog deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Configuration
NAMESPACE="web"
APP_LABEL="app=blog"
HPA_NAME="blog-hpa"
DEPLOYMENT_NAME="blog"

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is required but not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "kubectl is not connected to a cluster"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Function to create HPA
create_hpa() {
    log "Creating HorizontalPodAutoscaler..."
    
    local cpu_percent="${1:-60}"
    local min_replicas="${2:-2}"
    local max_replicas="${3:-10}"
    
    kubectl autoscale deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
        --cpu-percent="$cpu_percent" \
        --min="$min_replicas" \
        --max="$max_replicas" \
        --name="$HPA_NAME"
    
    success "HPA created with CPU target: ${cpu_percent}%, Min: ${min_replicas}, Max: ${max_replicas}"
}

# Function to show HPA status
show_hpa_status() {
    log "Showing HPA status..."
    
    echo ""
    highlight "HPA Status:"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    highlight "HPA Details:"
    kubectl describe hpa -n "$NAMESPACE" -l "$APP_LABEL"
    
    echo ""
    highlight "Current Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    highlight "Deployment Status:"
    kubectl get deployment -n "$NAMESPACE" -l "$APP_LABEL" -o wide
}

# Function to update HPA
update_hpa() {
    log "Updating HPA configuration..."
    
    local cpu_percent="${1:-60}"
    local min_replicas="${2:-2}"
    local max_replicas="${3:-10}"
    
    # Delete existing HPA
    kubectl delete hpa "$HPA_NAME" -n "$NAMESPACE" --ignore-not-found=true
    
    # Create new HPA
    create_hpa "$cpu_percent" "$min_replicas" "$max_replicas"
    
    success "HPA updated successfully"
}

# Function to delete HPA
delete_hpa() {
    log "Deleting HPA..."
    
    if kubectl delete hpa "$HPA_NAME" -n "$NAMESPACE"; then
        success "HPA deleted successfully"
    else
        warning "HPA not found or already deleted"
    fi
}

# Function to test autoscaling
test_autoscaling() {
    log "Testing autoscaling..."
    
    local test_duration="${1:-300}"  # 5 minutes default
    
    highlight "Starting autoscaling test for ${test_duration} seconds..."
    
    # Get initial status
    echo ""
    info "Initial Status:"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    # Create a load test pod to generate CPU load
    log "Creating load test pod..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: load-test-pod
  namespace: $NAMESPACE
spec:
  containers:
  - name: load-test
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Generating load...'; done"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
  restartPolicy: Never
EOF
    
    success "Load test pod created"
    
    # Monitor HPA for the test duration
    log "Monitoring HPA for ${test_duration} seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + test_duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        echo ""
        info "Current Status ($(date)):"
        kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | while read line; do
            echo "  $line"
        done
        
        kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | wc -l | xargs -I {} echo "  Pods: {}"
        
        sleep 30
    done
    
    # Clean up load test pod
    log "Cleaning up load test pod..."
    kubectl delete pod load-test-pod -n "$NAMESPACE" --ignore-not-found=true
    
    success "Autoscaling test completed"
    
    # Show final status
    echo ""
    highlight "Final Status:"
    show_hpa_status
}

# Function to monitor HPA
monitor_hpa() {
    log "Starting HPA monitoring..."
    
    while true; do
        clear
        echo "=== HPA Monitor - $(date) ==="
        echo ""
        
        # Show HPA status
        kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide
        echo ""
        
        # Show pod status
        kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
        echo ""
        
        # Show resource usage
        kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available"
        echo ""
        
        echo "Press Ctrl+C to stop monitoring..."
        sleep 10
    done
}

# Function to get HPA metrics
get_hpa_metrics() {
    log "Getting HPA metrics..."
    
    echo ""
    highlight "HPA Metrics:"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.currentCPUUtilizationPercentage}{"\t"}{.status.currentReplicas}{"\t"}{.spec.minReplicas}{"\t"}{.spec.maxReplicas}{"\n"}{end}' | column -t -N "HPA,CPU%,Current,Min,Max"
    
    echo ""
    highlight "Pod Resource Usage:"
    kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available"
    
    echo ""
    highlight "Node Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Node metrics not available"
}

# Function to scale manually
manual_scale() {
    local replicas="$1"
    
    if [ -z "$replicas" ]; then
        error "Please specify number of replicas"
        echo "Usage: $0 scale <number-of-replicas>"
        exit 1
    fi
    
    log "Manually scaling deployment to $replicas replicas..."
    
    kubectl scale deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --replicas="$replicas"
    
    success "Deployment scaled to $replicas replicas"
    
    # Show status
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
}

# Function to show help
show_help() {
    echo "HorizontalPodAutoscaler Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create [cpu%] [min] [max]  - Create HPA (default: 60% CPU, 2-10 replicas)"
    echo "  update [cpu%] [min] [max] - Update HPA configuration"
    echo "  delete                    - Delete HPA"
    echo "  status                    - Show HPA status"
    echo "  monitor                   - Monitor HPA in real-time"
    echo "  test [duration]           - Test autoscaling (default: 300s)"
    echo "  metrics                   - Show HPA metrics"
    echo "  scale <replicas>          - Manually scale deployment"
    echo "  help                      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create 70 3 15         # Create HPA with 70% CPU target, 3-15 replicas"
    echo "  $0 update 50 2 8          # Update HPA with 50% CPU target, 2-8 replicas"
    echo "  $0 test 600               # Test autoscaling for 10 minutes"
    echo "  $0 monitor                # Monitor HPA in real-time"
    echo "  $0 scale 5                # Manually scale to 5 replicas"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE                 - Kubernetes namespace (default: web)"
    echo "  APP_LABEL                 - App label selector (default: app=blog)"
    echo "  HPA_NAME                  - HPA name (default: blog-hpa)"
    echo "  DEPLOYMENT_NAME           - Deployment name (default: blog)"
}

# Main script logic
case "${1:-}" in
    "create")
        check_prerequisites
        create_hpa "$2" "$3" "$4"
        ;;
    "update")
        check_prerequisites
        update_hpa "$2" "$3" "$4"
        ;;
    "delete")
        check_prerequisites
        delete_hpa
        ;;
    "status")
        check_prerequisites
        show_hpa_status
        ;;
    "monitor")
        check_prerequisites
        monitor_hpa
        ;;
    "test")
        check_prerequisites
        test_autoscaling "$2"
        ;;
    "metrics")
        check_prerequisites
        get_hpa_metrics
        ;;
    "scale")
        check_prerequisites
        manual_scale "$2"
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "HorizontalPodAutoscaler Management Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 create    - Create HPA"
        echo "  $0 status    - Show HPA status"
        echo "  $0 monitor   - Monitor HPA"
        echo "  $0 test      - Test autoscaling"
        echo "  $0 help      - Show detailed help"
        ;;
esac
