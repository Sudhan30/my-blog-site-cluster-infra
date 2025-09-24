#!/bin/bash

# Kubernetes Blog Load Testing Script
# This script performs load testing on your blog deployment in Kubernetes

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
TEST_DURATION=60
CONCURRENT_USERS=10
REQUESTS_PER_SECOND=5

# Results directory
RESULTS_DIR="k8s-load-test-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Function to create results directory
create_results_dir() {
    if [ ! -d "$RESULTS_DIR" ]; then
        mkdir -p "$RESULTS_DIR"
        log "Created results directory: $RESULTS_DIR"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        error "kubectl is not connected to a cluster"
        echo "Please ensure kubectl is configured and connected to your cluster."
        exit 1
    fi
    
    success "All prerequisites found"
}

# Function to get blog service information
get_blog_service_info() {
    log "Getting blog service information..."
    
    local result_file="$RESULTS_DIR/service-info-${TIMESTAMP}.txt"
    
    echo "# Blog Service Information" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "" >> "$result_file"
    
    # Get service information
    echo "## Service Information" >> "$result_file"
    kubectl get svc -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
    
    # Get deployment information
    echo "" >> "$result_file"
    echo "## Deployment Information" >> "$result_file"
    kubectl get deployment -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
    
    # Get pod information
    echo "" >> "$result_file"
    echo "## Pod Information" >> "$result_file"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
    
    # Get ingress information
    echo "" >> "$result_file"
    echo "## Ingress Information" >> "$result_file"
    kubectl get ingress -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
    
    # Get service endpoints
    echo "" >> "$result_file"
    echo "## Service Endpoints" >> "$result_file"
    kubectl get endpoints -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
    
    success "Service information saved to $result_file"
}

# Function to get blog URL
get_blog_url() {
    log "Determining blog URL..."
    
    # Try to get URL from ingress
    local ingress_host=$(kubectl get ingress -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
    
    if [ -n "$ingress_host" ]; then
        BLOG_URL="https://$ingress_host"
        success "Found blog URL from ingress: $BLOG_URL"
    else
        # Try to get URL from service
        local service_port=$(kubectl get svc -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.ports[0].port}' 2>/dev/null || echo "")
        
        if [ -n "$service_port" ]; then
            # Try to port-forward to get local URL
            BLOG_URL="http://localhost:8080"
            success "Using port-forward URL: $BLOG_URL"
            info "Will set up port-forwarding for testing"
        else
            error "Could not determine blog URL"
            echo "Please provide the blog URL manually:"
            read -r BLOG_URL
        fi
    fi
}

# Function to set up port forwarding
setup_port_forward() {
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
        if curl -s -o /dev/null "http://localhost:8080/health" 2>/dev/null; then
            success "Port-forward established successfully"
            echo "$port_forward_pid" > "$RESULTS_DIR/port-forward-pid-${TIMESTAMP}.txt"
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
}

# Function to clean up port forwarding
cleanup_port_forward() {
    local pid_file="$RESULTS_DIR/port-forward-pid-${TIMESTAMP}.txt"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            log "Port-forward process $pid terminated"
        fi
        rm -f "$pid_file"
    fi
}

# Function to test pod resource usage
test_pod_resources() {
    log "Testing pod resource usage..."
    
    local result_file="$RESULTS_DIR/pod-resources-${TIMESTAMP}.txt"
    
    echo "# Pod Resource Usage Test" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "" >> "$result_file"
    
    # Get initial resource usage
    echo "## Initial Resource Usage" >> "$result_file"
    kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" >> "$result_file" 2>&1 || echo "kubectl top not available" >> "$result_file"
    
    # Get pod resource requests and limits
    echo "" >> "$result_file"
    echo "## Pod Resource Requests and Limits" >> "$result_file"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\t"}{.spec.containers[0].resources.limits.cpu}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}' >> "$result_file" 2>&1 || true
    
    success "Pod resource information saved to $result_file"
}

# Function to run load test against pods
run_pod_load_test() {
    log "Running load test against blog pods..."
    
    local result_file="$RESULTS_DIR/pod-load-test-${TIMESTAMP}.txt"
    local total_requests=100
    local concurrent_requests=5
    
    echo "# Pod Load Test Results" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "# Total requests: $total_requests" >> "$result_file"
    echo "# Concurrent requests: $concurrent_requests" >> "$result_file"
    echo "" >> "$result_file"
    
    local success_count=0
    local total_time=0
    local min_time=999999
    local max_time=0
    
    echo "## Individual Request Results" >> "$result_file"
    
    for ((i=1; i<=total_requests; i++)); do
        local start_time=$(date +%s.%N)
        
        if curl -s -o /dev/null -w "%{http_code},%{time_total},%{size_download}" "$BLOG_URL/health" >> "$result_file" 2>&1; then
            local end_time=$(date +%s.%N)
            local request_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            
            if (( $(echo "$request_time < $min_time" | bc -l 2>/dev/null || echo "0") )); then
                min_time=$request_time
            fi
            
            if (( $(echo "$request_time > $max_time" | bc -l 2>/dev/null || echo "0") )); then
                max_time=$request_time
            fi
            
            total_time=$(echo "$total_time + $request_time" | bc -l 2>/dev/null || echo "$total_time")
            success_count=$((success_count + 1))
        fi
        
        echo "" >> "$result_file"
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    
    echo ""
    
    # Calculate statistics
    local avg_time=$(echo "scale=3; $total_time / $success_count" | bc -l 2>/dev/null || echo "0")
    local success_rate=$(echo "scale=2; $success_count * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
    
    echo "" >> "$result_file"
    echo "## Summary Statistics" >> "$result_file"
    echo "Total requests: $total_requests" >> "$result_file"
    echo "Successful requests: $success_count" >> "$result_file"
    echo "Success rate: $success_rate%" >> "$result_file"
    echo "Average response time: ${avg_time}s" >> "$result_file"
    echo "Min response time: ${min_time}s" >> "$result_file"
    echo "Max response time: ${max_time}s" >> "$result_file"
    
    highlight "Pod Load Test Results:"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $success_count"
    echo "  Success rate: $success_rate%"
    echo "  Average response time: ${avg_time}s"
    echo "  Min response time: ${min_time}s"
    echo "  Max response time: ${max_time}s"
    
    success "Pod load test completed"
    success "Results saved to $result_file"
}

# Function to test pod scaling
test_pod_scaling() {
    log "Testing pod scaling..."
    
    local result_file="$RESULTS_DIR/pod-scaling-test-${TIMESTAMP}.txt"
    
    echo "# Pod Scaling Test Results" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "" >> "$result_file"
    
    # Get current replica count
    local current_replicas=$(kubectl get deployment -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.replicas}' 2>/dev/null || echo "0")
    echo "Current replicas: $current_replicas" >> "$result_file"
    
    # Scale up to 3 replicas
    log "Scaling up to 3 replicas..."
    if kubectl scale deployment -n "$NAMESPACE" -l "$APP_LABEL" --replicas=3 >> "$result_file" 2>&1; then
        success "Scaled up to 3 replicas"
        
        # Wait for scaling to complete
        log "Waiting for scaling to complete..."
        kubectl rollout status deployment -n "$NAMESPACE" -l "$APP_LABEL" --timeout=300s >> "$result_file" 2>&1 || true
        
        # Get new replica count
        local new_replicas=$(kubectl get deployment -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[0].spec.replicas}' 2>/dev/null || echo "0")
        echo "New replicas: $new_replicas" >> "$result_file"
        
        # Get pod status
        echo "" >> "$result_file"
        echo "## Pod Status After Scaling" >> "$result_file"
        kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
        
        # Scale back to original
        log "Scaling back to $current_replicas replicas..."
        if kubectl scale deployment -n "$NAMESPACE" -l "$APP_LABEL" --replicas="$current_replicas" >> "$result_file" 2>&1; then
            success "Scaled back to $current_replicas replicas"
        else
            warning "Failed to scale back to original replica count"
        fi
    else
        error "Failed to scale up deployment"
    fi
    
    success "Pod scaling test completed"
    success "Results saved to $result_file"
}

# Function to test pod health under load
test_pod_health_under_load() {
    log "Testing pod health under load..."
    
    local result_file="$RESULTS_DIR/pod-health-load-test-${TIMESTAMP}.txt"
    local duration=30
    local concurrent_users=20
    
    echo "# Pod Health Under Load Test" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "# Duration: ${duration}s" >> "$result_file"
    echo "# Concurrent users: $concurrent_users" >> "$result_file"
    echo "" >> "$result_file"
    
    # Get initial pod status
    echo "## Initial Pod Status" >> "$result_file"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
    
    # Run load test
    log "Running load test for $duration seconds..."
    local pids=()
    local success_count=0
    local total_requests=0
    
    for ((i=1; i<=concurrent_users; i++)); do
        (
            local user_success=0
            local user_requests=0
            local start_time=$(date +%s)
            
            while [ $(($(date +%s) - start_time)) -lt $duration ]; do
                if curl -s -o /dev/null -w "%{http_code}" "$BLOG_URL/health" | grep -q "200"; then
                    user_success=$((user_success + 1))
                fi
                user_requests=$((user_requests + 1))
                sleep 0.1
            done
            
            echo "User $i: $user_success/$user_requests successful" >> "$result_file"
        ) &
        pids+=($!)
    done
    
    # Wait for all processes to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    # Get final pod status
    echo "" >> "$result_file"
    echo "## Final Pod Status" >> "$result_file"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide >> "$result_file" 2>&1 || true
    
    # Calculate totals
    success_count=$(grep "User" "$result_file" | awk -F: '{sum+=$2} END {print sum}')
    total_requests=$(grep "User" "$result_file" | awk -F/ '{sum+=$2} END {print sum}')
    
    local success_rate=$(echo "scale=2; $success_count * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
    
    echo "" >> "$result_file"
    echo "## Load Test Summary" >> "$result_file"
    echo "Total requests: $total_requests" >> "$result_file"
    echo "Successful requests: $success_count" >> "$result_file"
    echo "Success rate: $success_rate%" >> "$result_file"
    
    highlight "Pod Health Under Load Results:"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $success_count"
    echo "  Success rate: $success_rate%"
    
    success "Pod health under load test completed"
    success "Results saved to $result_file"
}

# Function to generate Kubernetes performance report
generate_k8s_performance_report() {
    log "Generating Kubernetes performance report..."
    
    local report_file="$RESULTS_DIR/k8s-performance-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# Kubernetes Blog Performance Report

**Generated:** $(date)  
**Namespace:** $NAMESPACE  
**App Label:** $APP_LABEL  
**Blog URL:** $BLOG_URL  
**Test Duration:** $TEST_DURATION seconds  
**Concurrent Users:** $CONCURRENT_USERS  

## Test Summary

This report contains the results of comprehensive load testing performed on your blog deployment in Kubernetes.

## Test Results

EOF
    
    # Add results from each test
    for test_file in "$RESULTS_DIR"/*-${TIMESTAMP}.txt; do
        if [ -f "$test_file" ]; then
            local test_name=$(basename "$test_file" | sed 's/-[0-9]\{8\}-[0-9]\{6\}\.txt$//' | tr '-' ' ' | sed 's/\b\w/\U&/g')
            echo "### $test_name" >> "$report_file"
            echo "" >> "$report_file"
            echo '```' >> "$report_file"
            cat "$test_file" >> "$report_file"
            echo '```' >> "$report_file"
            echo "" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Kubernetes Performance Recommendations

Based on the test results, consider the following optimizations:

### High Priority
- Monitor pod resource usage under load
- Implement horizontal pod autoscaling (HPA)
- Optimize resource requests and limits
- Implement pod disruption budgets

### Medium Priority
- Implement vertical pod autoscaling (VPA)
- Add monitoring and alerting
- Optimize container images
- Implement readiness and liveness probes

### Low Priority
- Implement pod anti-affinity rules
- Use node affinity for better performance
- Implement pod security policies
- Consider using dedicated nodes

## Monitoring

Set up continuous monitoring to track:
- Pod resource utilization
- Response times
- Error rates
- Scaling events
- Node resource usage

## Next Steps

1. Review the test results
2. Identify performance bottlenecks
3. Implement optimizations
4. Re-run tests to validate improvements
5. Set up continuous monitoring
6. Implement autoscaling policies

---
*Report generated by k8s-load-test.sh*
EOF
    
    success "Kubernetes performance report generated: $report_file"
}

# Function to show test results summary
show_k8s_test_summary() {
    echo ""
    highlight "Kubernetes Load Test Summary"
    echo "=============================="
    echo "Namespace: $NAMESPACE"
    echo "App Label: $APP_LABEL"
    echo "Blog URL: $BLOG_URL"
    echo "Test Duration: $TEST_DURATION seconds"
    echo "Concurrent Users: $CONCURRENT_USERS"
    echo "Results Directory: $RESULTS_DIR"
    echo ""
    
    echo "Test Results:"
    ls -la "$RESULTS_DIR"/*-${TIMESTAMP}.* 2>/dev/null || echo "No test results found"
    echo ""
    
    echo "Performance Report:"
    echo "  $RESULTS_DIR/k8s-performance-report-${TIMESTAMP}.md"
    echo ""
    
    echo "To view results:"
    echo "  cat $RESULTS_DIR/k8s-performance-report-${TIMESTAMP}.md"
    echo "  less $RESULTS_DIR/k8s-performance-report-${TIMESTAMP}.md"
}

# Main test function
run_k8s_load_tests() {
    log "Starting Kubernetes load testing..."
    
    create_results_dir
    check_prerequisites
    get_blog_service_info
    get_blog_url
    
    # Set up port forwarding if needed
    if [[ "$BLOG_URL" == http://localhost:* ]]; then
        if ! setup_port_forward; then
            error "Failed to set up port forwarding"
            exit 1
        fi
    fi
    
    # Run all tests
    test_pod_resources
    run_pod_load_test
    test_pod_scaling
    test_pod_health_under_load
    
    # Generate report
    generate_k8s_performance_report
    
    # Clean up port forwarding
    cleanup_port_forward
    
    success "All Kubernetes load tests completed!"
    show_k8s_test_summary
}

# Main script logic
case "${1:-}" in
    "test")
        run_k8s_load_tests
        ;;
    "service-info")
        create_results_dir
        check_prerequisites
        get_blog_service_info
        ;;
    "pod-resources")
        create_results_dir
        check_prerequisites
        test_pod_resources
        ;;
    "pod-load")
        create_results_dir
        check_prerequisites
        get_blog_url
        if [[ "$BLOG_URL" == http://localhost:* ]]; then
            setup_port_forward
        fi
        run_pod_load_test
        cleanup_port_forward
        ;;
    "pod-scaling")
        create_results_dir
        check_prerequisites
        test_pod_scaling
        ;;
    "pod-health")
        create_results_dir
        check_prerequisites
        get_blog_url
        if [[ "$BLOG_URL" == http://localhost:* ]]; then
            setup_port_forward
        fi
        test_pod_health_under_load
        cleanup_port_forward
        ;;
    "check")
        check_prerequisites
        ;;
    "help"|"-h"|"--help")
        echo "Kubernetes Blog Load Testing Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  test           - Run all Kubernetes load tests (default)"
        echo "  service-info   - Get service information only"
        echo "  pod-resources  - Test pod resource usage only"
        echo "  pod-load       - Run pod load test only"
        echo "  pod-scaling    - Test pod scaling only"
        echo "  pod-health     - Test pod health under load only"
        echo "  check          - Check prerequisites only"
        echo "  help           - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  NAMESPACE           - Kubernetes namespace (default: web)"
        echo "  APP_LABEL           - App label selector (default: app=blog)"
        echo "  TEST_DURATION       - Test duration in seconds (default: 60)"
        echo "  CONCURRENT_USERS    - Number of concurrent users (default: 10)"
        echo "  REQUESTS_PER_SECOND - Requests per second (default: 5)"
        echo ""
        echo "Examples:"
        echo "  $0 test                                    # Run all tests"
        echo "  $0 service-info                            # Get service info only"
        echo "  $0 pod-load                                # Run pod load test"
        echo "  NAMESPACE=production $0 test               # Test in production namespace"
        echo "  TEST_DURATION=120 $0 test                 # Run tests for 2 minutes"
        echo ""
        echo "Prerequisites:"
        echo "  - kubectl configured and connected to cluster"
        echo "  - curl (usually pre-installed)"
        echo "  - Blog deployment running in Kubernetes"
        echo ""
        echo "Results:"
        echo "  All test results are saved in the 'k8s-load-test-results' directory"
        echo "  A comprehensive performance report is generated in Markdown format"
        ;;
    *)
        echo "Kubernetes Blog Load Testing Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 test        - Run all Kubernetes load tests"
        echo "  $0 check       - Check prerequisites"
        echo "  $0 help        - Show detailed help"
        ;;
esac
