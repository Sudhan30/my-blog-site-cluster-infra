#!/bin/bash

# HPA Load Testing Script
# This script generates load to test HorizontalPodAutoscaler

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
BLOG_URL=""
LOAD_DURATION=300  # 5 minutes
CONCURRENT_USERS=20
REQUESTS_PER_SECOND=10

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
    
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed"
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
                echo "$port_forward_pid" > /tmp/hpa-load-test-pid
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
    local pid_file="/tmp/hpa-load-test-pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            log "Port-forward process $pid terminated"
        fi
        rm -f "$pid_file"
    fi
}

# Function to show initial status
show_initial_status() {
    log "Showing initial status..."
    
    echo ""
    highlight "Initial HPA Status:"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    highlight "Initial Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    highlight "Initial Resource Usage:"
    kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available"
}

# Function to generate load
generate_load() {
    log "Generating load for ${LOAD_DURATION} seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + LOAD_DURATION))
    
    # Create load generation processes
    local pids=()
    
    for ((i=1; i<=CONCURRENT_USERS; i++)); do
        (
            local user_requests=0
            local user_success=0
            
            while [ $(date +%s) -lt $end_time ]; do
                if curl -s -o /dev/null -w "%{http_code}" "$BLOG_URL" | grep -q "200"; then
                    user_success=$((user_success + 1))
                fi
                user_requests=$((user_requests + 1))
                
                # Control request rate
                sleep $((1 / REQUESTS_PER_SECOND))
            done
            
            echo "User $i: $user_success/$user_requests successful"
        ) &
        pids+=($!)
    done
    
    # Monitor HPA during load generation
    log "Monitoring HPA during load generation..."
    
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
    
    # Wait for all load generation processes to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    success "Load generation completed"
}

# Function to show final status
show_final_status() {
    log "Showing final status..."
    
    echo ""
    highlight "Final HPA Status:"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    highlight "Final Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    
    echo ""
    highlight "Final Resource Usage:"
    kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available"
    
    echo ""
    highlight "HPA Events:"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name=blog-hpa --sort-by='.lastTimestamp' | tail -10
}

# Function to create load test report
create_load_test_report() {
    log "Creating load test report..."
    
    local report_file="hpa-load-test-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# HPA Load Test Report

**Generated:** $(date)  
**Namespace:** $NAMESPACE  
**App Label:** $APP_LABEL  
**Blog URL:** $BLOG_URL  
**Load Duration:** $LOAD_DURATION seconds  
**Concurrent Users:** $CONCURRENT_USERS  
**Requests per Second:** $REQUESTS_PER_SECOND  

## Test Summary

This report contains the results of load testing performed on the HorizontalPodAutoscaler.

## Test Results

### HPA Status
\`\`\`
$(kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide)
\`\`\`

### Pod Status
\`\`\`
$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide)
\`\`\`

### Resource Usage
\`\`\`
$(kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available")
\`\`\`

### HPA Events
\`\`\`
$(kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name=blog-hpa --sort-by='.lastTimestamp' | tail -10)
\`\`\`

## Analysis

### Scaling Behavior
- **Initial Replicas:** $(kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].status.currentReplicas}' 2>/dev/null || echo "N/A")
- **Target Replicas:** $(kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].status.desiredReplicas}' 2>/dev/null || echo "N/A")
- **CPU Utilization:** $(kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].status.currentCPUUtilizationPercentage}' 2>/dev/null || echo "N/A")%

### Performance Metrics
- **Load Duration:** $LOAD_DURATION seconds
- **Concurrent Users:** $CONCURRENT_USERS
- **Total Requests:** $((CONCURRENT_USERS * REQUESTS_PER_SECOND * LOAD_DURATION))

## Recommendations

Based on the test results:

1. **Monitor CPU utilization** during peak load
2. **Adjust HPA thresholds** if needed
3. **Consider memory-based scaling** for memory-intensive workloads
4. **Implement custom metrics** for more precise scaling
5. **Set up alerting** for scaling events

---
*Report generated by test-hpa-load.sh*
EOF
    
    success "Load test report created: $report_file"
}

# Function to run complete HPA load test
run_hpa_load_test() {
    log "Starting HPA load test..."
    
    check_prerequisites
    get_blog_url
    
    # Set up port forwarding if needed
    if [[ "$BLOG_URL" == http://localhost:* ]]; then
        if ! setup_port_forward; then
            error "Failed to set up port forwarding"
            exit 1
        fi
    fi
    
    # Show initial status
    show_initial_status
    
    # Generate load
    generate_load
    
    # Show final status
    show_final_status
    
    # Create report
    create_load_test_report
    
    # Clean up port forwarding
    cleanup_port_forward
    
    success "HPA load test completed!"
}

# Function to show help
show_help() {
    echo "HPA Load Testing Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --duration <seconds>      - Load test duration (default: 300)"
    echo "  --users <number>          - Number of concurrent users (default: 20)"
    echo "  --rps <number>            - Requests per second (default: 10)"
    echo "  --url <url>               - Blog URL to test"
    echo "  --namespace <namespace>   - Kubernetes namespace (default: web)"
    echo "  --help                    - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Run with default settings"
    echo "  $0 --duration 600         # Run for 10 minutes"
    echo "  $0 --users 50 --rps 20    # 50 users, 20 RPS"
    echo "  $0 --url https://myblog.com # Test specific URL"
    echo ""
    echo "Environment Variables:"
    echo "  BLOG_URL                  - Blog URL to test"
    echo "  LOAD_DURATION             - Load test duration in seconds"
    echo "  CONCURRENT_USERS          - Number of concurrent users"
    echo "  REQUESTS_PER_SECOND       - Requests per second"
    echo "  NAMESPACE                 - Kubernetes namespace"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --duration)
            LOAD_DURATION="$2"
            shift 2
            ;;
        --users)
            CONCURRENT_USERS="$2"
            shift 2
            ;;
        --rps)
            REQUESTS_PER_SECOND="$2"
            shift 2
            ;;
        --url)
            BLOG_URL="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
run_hpa_load_test
