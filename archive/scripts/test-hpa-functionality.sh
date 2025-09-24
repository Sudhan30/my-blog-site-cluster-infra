#!/bin/bash

# HPA Functionality Testing Script
# This script tests if HPA is working as expected

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
BLOG_URL=""

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

# Function to get blog URL
get_blog_url() {
    if [ -z "$BLOG_URL" ]; then
        # Try to get URL from ingress
        local ingress_host=$(kubectl get ingress -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
        
        if [ -n "$ingress_host" ]; then
            BLOG_URL="https://$ingress_host"
            success "Found blog URL from ingress: $BLOG_URL"
        else
            # Try to get URL from service
            local service_port=$(kubectl get svc -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.ports[0].port}' 2>/dev/null || echo "")
            
            if [ -n "$service_port" ]; then
                BLOG_URL="http://localhost:8080"
                success "Using port-forward URL: $BLOG_URL"
                info "Will set up port-forwarding for testing"
            else
                error "Could not determine blog URL"
                echo "Please provide the blog URL manually:"
                read -r BLOG_URL
            fi
        fi
    fi
}

# Function to set up port forwarding
setup_port_forward() {
    if [[ "$BLOG_URL" == http://localhost:* ]]; then
        log "Setting up port forwarding..."
        
        local service_name=$(kubectl get svc -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        local service_port=$(kubectl get svc -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.ports[0].port}' 2>/dev/null || echo "")
        
        if [ -n "$service_name" ] && [ -n "$service_port" ]; then
            log "Starting port-forward for $service_name:$service_port"
            
            # Start port-forward in background
            kubectl port-forward -n "$NAMESPACE" "svc/$service_name" 8080:"$service_port" > /dev/null 2>&1 &
            local port_forward_pid=$!
            
            # Wait for port-forward to be ready
            sleep 3
            
            # Test if port-forward is working
            if curl -s -o /dev/null "$BLOG_URL/health" 2>/dev/null; then
                success "Port-forward established successfully"
                echo "$port_forward_pid" > /tmp/hpa-test-pid
                return 0
            else
                error "Port-forward failed"
                kill $port_forward_pid 2>/dev/null || true
                return 1
            fi
        else
            error "Could not set up port-forwarding"
            return 1
        fi
    fi
}

# Function to clean up port forwarding
cleanup_port_forward() {
    local pid_file="/tmp/hpa-test-pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            log "Port-forward process $pid terminated"
        fi
        rm -f "$pid_file"
    fi
}

# Function to check HPA exists and is configured
check_hpa_exists() {
    log "Checking if HPA exists and is configured..."
    
    if kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" &>/dev/null; then
        success "HPA '$HPA_NAME' exists"
        
        # Show HPA configuration
        echo ""
        highlight "HPA Configuration:"
        kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" -o wide
        
        echo ""
        highlight "HPA Details:"
        kubectl describe hpa "$HPA_NAME" -n "$NAMESPACE"
        
        return 0
    else
        error "HPA '$HPA_NAME' not found in namespace '$NAMESPACE'"
        return 1
    fi
}

# Function to check deployment has resource requests
check_deployment_resources() {
    log "Checking deployment resource configuration..."
    
    local cpu_request=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
    local memory_request=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
    
    if [ -n "$cpu_request" ] && [ -n "$memory_request" ]; then
        success "Deployment has resource requests configured"
        echo "  CPU Request: $cpu_request"
        echo "  Memory Request: $memory_request"
        return 0
    else
        error "Deployment missing resource requests (required for HPA)"
        echo "  CPU Request: $cpu_request"
        echo "  Memory Request: $memory_request"
        return 1
    fi
}

# Function to check metrics server
check_metrics_server() {
    log "Checking metrics server availability..."
    
    if kubectl top nodes &>/dev/null; then
        success "Metrics server is available"
        
        echo ""
        highlight "Node Resource Usage:"
        kubectl top nodes
        
        echo ""
        highlight "Pod Resource Usage:"
        kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "No pods found"
        
        return 0
    else
        error "Metrics server not available (required for HPA)"
        echo "Install metrics server: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
        return 1
    fi
}

# Function to get initial status
get_initial_status() {
    log "Getting initial status..."
    
    echo ""
    highlight "=== Initial Status ==="
    
    echo ""
    info "HPA Status:"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    info "Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    info "Deployment Status:"
    kubectl get deployment -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    info "Resource Usage:"
    kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available"
}

# Function to generate CPU load
generate_cpu_load() {
    local duration="${1:-300}"  # 5 minutes default
    local intensity="${2:-high}"  # low, medium, high
    
    log "Generating CPU load for ${duration} seconds (intensity: $intensity)..."
    
    # Create a load generation pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-load-generator
  namespace: $NAMESPACE
spec:
  containers:
  - name: load-generator
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Generating CPU load...'; done"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
  restartPolicy: Never
EOF
    
    success "CPU load generator pod created"
    
    # Monitor HPA during load generation
    log "Monitoring HPA during load generation..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        echo ""
        info "Current Status ($(date)):"
        
        # Show HPA status
        kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | while read line; do
            echo "  HPA: $line"
        done
        
        # Show pod count
        local pod_count=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | wc -l)
        echo "  Pods: $pod_count"
        
        # Show resource usage
        kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers 2>/dev/null | head -3 | while read line; do
            echo "  $line"
        done
        
        sleep 30
    done
    
    # Clean up load generator
    log "Cleaning up CPU load generator..."
    kubectl delete pod cpu-load-generator -n "$NAMESPACE" --ignore-not-found=true
    
    success "CPU load generation completed"
}

# Function to generate HTTP load
generate_http_load() {
    local duration="${1:-300}"  # 5 minutes default
    local concurrent_users="${2:-50}"
    
    log "Generating HTTP load for ${duration} seconds with $concurrent_users concurrent users..."
    
    # Create HTTP load generation pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: http-load-generator
  namespace: $NAMESPACE
spec:
  containers:
  - name: load-generator
    image: curlimages/curl
    command: ["/bin/sh"]
    args: ["-c", "while true; do curl -s $BLOG_URL > /dev/null; sleep 0.1; done"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
  restartPolicy: Never
EOF
    
    success "HTTP load generator pod created"
    
    # Monitor HPA during load generation
    log "Monitoring HPA during HTTP load generation..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        echo ""
        info "Current Status ($(date)):"
        
        # Show HPA status
        kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | while read line; do
            echo "  HPA: $line"
        done
        
        # Show pod count
        local pod_count=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | wc -l)
        echo "  Pods: $pod_count"
        
        # Show resource usage
        kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers 2>/dev/null | head -3 | while read line; do
            echo "  $line"
        done
        
        sleep 30
    done
    
    # Clean up load generator
    log "Cleaning up HTTP load generator..."
    kubectl delete pod http-load-generator -n "$NAMESPACE" --ignore-not-found=true
    
    success "HTTP load generation completed"
}

# Function to test scale down
test_scale_down() {
    log "Testing scale down behavior..."
    
    # Wait for load to decrease and HPA to scale down
    log "Waiting for HPA to scale down (this may take several minutes)..."
    
    local start_time=$(date +%s)
    local timeout=600  # 10 minutes timeout
    
    while [ $(date +%s) -lt $((start_time + timeout)) ]; do
        local current_replicas=$(kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].status.currentReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].status.desiredReplicas}' 2>/dev/null || echo "0")
        local min_replicas=$(kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.minReplicas}' 2>/dev/null || echo "0")
        
        echo ""
        info "Scale Down Status ($(date)):"
        echo "  Current Replicas: $current_replicas"
        echo "  Desired Replicas: $desired_replicas"
        echo "  Min Replicas: $min_replicas"
        
        if [ "$current_replicas" -eq "$min_replicas" ]; then
            success "HPA has scaled down to minimum replicas ($min_replicas)"
            break
        fi
        
        sleep 60
    done
    
    if [ $(date +%s) -ge $((start_time + timeout)) ]; then
        warning "Timeout waiting for scale down"
    fi
}

# Function to get final status
get_final_status() {
    log "Getting final status..."
    
    echo ""
    highlight "=== Final Status ==="
    
    echo ""
    info "HPA Status:"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    info "Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    info "Deployment Status:"
    kubectl get deployment -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    info "Resource Usage:"
    kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available"
    
    echo ""
    info "HPA Events:"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$HPA_NAME" --sort-by='.lastTimestamp' | tail -10
}

# Function to run complete HPA test
run_complete_hpa_test() {
    log "Running complete HPA functionality test..."
    
    check_prerequisites
    get_blog_url
    
    # Set up port forwarding if needed
    if [[ "$BLOG_URL" == http://localhost:* ]]; then
        if ! setup_port_forward; then
            error "Failed to set up port forwarding"
            exit 1
        fi
    fi
    
    # Check HPA prerequisites
    if ! check_hpa_exists; then
        error "HPA not found or not configured"
        exit 1
    fi
    
    if ! check_deployment_resources; then
        error "Deployment missing resource requests"
        exit 1
    fi
    
    if ! check_metrics_server; then
        error "Metrics server not available"
        exit 1
    fi
    
    # Get initial status
    get_initial_status
    
    # Generate load and test scaling
    generate_cpu_load 300 high
    generate_http_load 300 50
    
    # Test scale down
    test_scale_down
    
    # Get final status
    get_final_status
    
    # Clean up port forwarding
    cleanup_port_forward
    
    success "Complete HPA functionality test completed!"
}

# Function to show help
show_help() {
    echo "HPA Functionality Testing Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  test                    - Run complete HPA functionality test"
    echo "  check                   - Check HPA prerequisites only"
    echo "  cpu-load [duration]     - Generate CPU load (default: 300s)"
    echo "  http-load [duration] [users] - Generate HTTP load (default: 300s, 50 users)"
    echo "  scale-down              - Test scale down behavior"
    echo "  status                  - Show current HPA status"
    echo "  help                    - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 test                 # Run complete HPA test"
    echo "  $0 check                # Check prerequisites only"
    echo "  $0 cpu-load 600         # Generate CPU load for 10 minutes"
    echo "  $0 http-load 300 100    # Generate HTTP load with 100 users"
    echo "  $0 status               # Show current status"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE               - Kubernetes namespace (default: web)"
    echo "  APP_LABEL               - App label selector (default: app=blog)"
    echo "  HPA_NAME                - HPA name (default: blog-hpa)"
    echo "  DEPLOYMENT_NAME         - Deployment name (default: blog)"
    echo "  BLOG_URL                - Blog URL to test"
}

# Main script logic
case "${1:-}" in
    "test")
        run_complete_hpa_test
        ;;
    "check")
        check_prerequisites
        check_hpa_exists
        check_deployment_resources
        check_metrics_server
        ;;
    "cpu-load")
        check_prerequisites
        get_blog_url
        if [[ "$BLOG_URL" == http://localhost:* ]]; then
            setup_port_forward
        fi
        generate_cpu_load "$2" "$3"
        cleanup_port_forward
        ;;
    "http-load")
        check_prerequisites
        get_blog_url
        if [[ "$BLOG_URL" == http://localhost:* ]]; then
            setup_port_forward
        fi
        generate_http_load "$2" "$3"
        cleanup_port_forward
        ;;
    "scale-down")
        check_prerequisites
        test_scale_down
        ;;
    "status")
        check_prerequisites
        get_initial_status
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "HPA Functionality Testing Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 test        - Run complete HPA test"
        echo "  $0 check       - Check prerequisites"
        echo "  $0 status      - Show current status"
        echo "  $0 help        - Show detailed help"
        ;;
esac
