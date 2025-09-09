#!/bin/bash

# Simple Blog Load Testing Script
# This script performs basic load testing using only curl (no additional tools required)

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
BLOG_URL=""
TEST_DURATION=30
CONCURRENT_USERS=5
REQUESTS_PER_USER=20

# Results directory
RESULTS_DIR="simple-load-test-results"
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
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed"
        echo "Please install curl and try again."
        exit 1
    fi
    
    success "All prerequisites found (curl)"
}

# Function to get blog URL
get_blog_url() {
    if [ -z "$BLOG_URL" ]; then
        echo "Enter your blog URL (e.g., https://yourblog.com or http://yourblog.com):"
        read -r BLOG_URL
        
        if [ -z "$BLOG_URL" ]; then
            error "Blog URL is required"
            exit 1
        fi
        
        log "Blog URL: $BLOG_URL"
    fi
}

# Function to test basic connectivity
test_connectivity() {
    log "Testing basic connectivity..."
    
    local result_file="$RESULTS_DIR/connectivity-test-${TIMESTAMP}.txt"
    
    echo "# Basic Connectivity Test Results" > "$result_file"
    echo "# Tested: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "" >> "$result_file"
    
    # Test basic HTTP response
    echo "## Basic HTTP Response Test" >> "$result_file"
    if curl -s -o /dev/null -w "HTTP Status: %{http_code}\nResponse Time: %{time_total}s\nTotal Time: %{time_total}s\n" "$BLOG_URL" >> "$result_file"; then
        success "Basic connectivity test completed"
    else
        error "Basic connectivity test failed"
        return 1
    fi
    
    # Test health endpoint if available
    echo "" >> "$result_file"
    echo "## Health Endpoint Test" >> "$result_file"
    if curl -s -o /dev/null -w "HTTP Status: %{http_code}\nResponse Time: %{time_total}s\n" "$BLOG_URL/health" >> "$result_file"; then
        success "Health endpoint test completed"
    else
        warning "Health endpoint not available or failed"
    fi
    
    success "Connectivity test results saved to $result_file"
}

# Function to run simple load test
run_simple_load_test() {
    log "Running simple load test..."
    
    local result_file="$RESULTS_DIR/simple-load-test-${TIMESTAMP}.txt"
    
    echo "# Simple Load Test Results" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "# Concurrent users: $CONCURRENT_USERS" >> "$result_file"
    echo "# Requests per user: $REQUESTS_PER_USER" >> "$result_file"
    echo "" >> "$result_file"
    
    local success_count=0
    local total_requests=0
    local total_time=0
    local min_time=999999
    local max_time=0
    
    echo "## Individual Request Results" >> "$result_file"
    
    # Run load test
    for ((user=1; user<=CONCURRENT_USERS; user++)); do
        log "Starting user $user..."
        
        for ((req=1; req<=REQUESTS_PER_USER; req++)); do
            local start_time=$(date +%s.%N)
            
            if curl -s -o /dev/null -w "%{http_code},%{time_total},%{size_download}" "$BLOG_URL" >> "$result_file" 2>&1; then
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
            
            total_requests=$((total_requests + 1))
            echo "" >> "$result_file"
            
            # Progress indicator
            if [ $((req % 5)) -eq 0 ]; then
                echo -n "."
            fi
        done
        
        echo ""
        log "User $user completed"
    done
    
    # Calculate statistics
    local avg_time=$(echo "scale=3; $total_time / $success_count" | bc -l 2>/dev/null || echo "0")
    local success_rate=$(echo "scale=2; $success_count * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
    local requests_per_second=$(echo "scale=2; $success_count / $TEST_DURATION" | bc -l 2>/dev/null || echo "0")
    
    echo "" >> "$result_file"
    echo "## Summary Statistics" >> "$result_file"
    echo "Total requests: $total_requests" >> "$result_file"
    echo "Successful requests: $success_count" >> "$result_file"
    echo "Success rate: $success_rate%" >> "$result_file"
    echo "Average response time: ${avg_time}s" >> "$result_file"
    echo "Min response time: ${min_time}s" >> "$result_file"
    echo "Max response time: ${max_time}s" >> "$result_file"
    echo "Requests per second: $requests_per_second" >> "$result_file"
    
    highlight "Simple Load Test Results:"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $success_count"
    echo "  Success rate: $success_rate%"
    echo "  Average response time: ${avg_time}s"
    echo "  Min response time: ${min_time}s"
    echo "  Max response time: ${max_time}s"
    echo "  Requests per second: $requests_per_second"
    
    success "Simple load test completed"
    success "Results saved to $result_file"
}

# Function to run stress test
run_stress_test() {
    log "Running stress test..."
    
    local result_file="$RESULTS_DIR/stress-test-${TIMESTAMP}.txt"
    local duration=20
    local concurrent_users=10
    
    echo "# Stress Test Results" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "# Duration: ${duration}s" >> "$result_file"
    echo "# Concurrent users: $concurrent_users" >> "$result_file"
    echo "" >> "$result_file"
    
    # Run multiple curl processes in parallel
    local pids=()
    local success_count=0
    local total_requests=0
    
    for ((i=1; i<=concurrent_users; i++)); do
        (
            local user_success=0
            local user_requests=0
            local start_time=$(date +%s)
            
            while [ $(($(date +%s) - start_time)) -lt $duration ]; do
                if curl -s -o /dev/null -w "%{http_code}" "$BLOG_URL" | grep -q "200"; then
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
    
    # Calculate totals
    success_count=$(grep "User" "$result_file" | awk -F: '{sum+=$2} END {print sum}')
    total_requests=$(grep "User" "$result_file" | awk -F/ '{sum+=$2} END {print sum}')
    
    local success_rate=$(echo "scale=2; $success_count * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
    
    echo "" >> "$result_file"
    echo "## Stress Test Summary" >> "$result_file"
    echo "Total requests: $total_requests" >> "$result_file"
    echo "Successful requests: $success_count" >> "$result_file"
    echo "Success rate: $success_rate%" >> "$result_file"
    
    highlight "Stress Test Results:"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $success_count"
    echo "  Success rate: $success_rate%"
    
    success "Stress test completed"
    success "Results saved to $result_file"
}

# Function to test response time under load
test_response_time_under_load() {
    log "Testing response time under load..."
    
    local result_file="$RESULTS_DIR/response-time-test-${TIMESTAMP}.txt"
    local concurrent_users=5
    local requests_per_user=10
    
    echo "# Response Time Under Load Test" > "$result_file"
    echo "# Generated: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "# Concurrent users: $concurrent_users" >> "$result_file"
    echo "# Requests per user: $requests_per_user" >> "$result_file"
    echo "" >> "$result_file"
    
    local success_count=0
    local total_requests=0
    local total_time=0
    local min_time=999999
    local max_time=0
    
    echo "## Individual Request Results" >> "$result_file"
    
    # Run response time test
    for ((user=1; user<=concurrent_users; user++)); do
        for ((req=1; req<=requests_per_user; req++)); do
            local start_time=$(date +%s.%N)
            
            if curl -s -o /dev/null -w "%{http_code},%{time_total},%{size_download}" "$BLOG_URL" >> "$result_file" 2>&1; then
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
            
            total_requests=$((total_requests + 1))
            echo "" >> "$result_file"
        done
    done
    
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
    
    highlight "Response Time Under Load Results:"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $success_count"
    echo "  Success rate: $success_rate%"
    echo "  Average response time: ${avg_time}s"
    echo "  Min response time: ${min_time}s"
    echo "  Max response time: ${max_time}s"
    
    success "Response time under load test completed"
    success "Results saved to $result_file"
}

# Function to generate simple performance report
generate_simple_performance_report() {
    log "Generating simple performance report..."
    
    local report_file="$RESULTS_DIR/simple-performance-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# Blog Site Simple Performance Report

**Generated:** $(date)  
**Blog URL:** $BLOG_URL  
**Test Duration:** $TEST_DURATION seconds  
**Concurrent Users:** $CONCURRENT_USERS  

## Test Summary

This report contains the results of simple load testing performed on your blog site using only curl.

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

## Simple Performance Recommendations

Based on the test results, consider the following optimizations:

### High Priority
- Monitor response times under load
- Implement caching strategies
- Optimize database queries
- Use CDN for static assets

### Medium Priority
- Implement rate limiting
- Add monitoring and alerting
- Optimize images and assets
- Consider horizontal scaling

### Low Priority
- Implement compression
- Optimize CSS and JavaScript
- Use HTTP/2
- Implement service worker caching

## Monitoring

Set up continuous monitoring to track:
- Response times
- Error rates
- Resource utilization
- User experience metrics

## Next Steps

1. Review the test results
2. Identify performance bottlenecks
3. Implement optimizations
4. Re-run tests to validate improvements
5. Set up continuous monitoring

---
*Report generated by simple-load-test.sh*
EOF
    
    success "Simple performance report generated: $report_file"
}

# Function to show test results summary
show_simple_test_summary() {
    echo ""
    highlight "Simple Load Test Summary"
    echo "=========================="
    echo "Blog URL: $BLOG_URL"
    echo "Test Duration: $TEST_DURATION seconds"
    echo "Concurrent Users: $CONCURRENT_USERS"
    echo "Results Directory: $RESULTS_DIR"
    echo ""
    
    echo "Test Results:"
    ls -la "$RESULTS_DIR"/*-${TIMESTAMP}.* 2>/dev/null || echo "No test results found"
    echo ""
    
    echo "Performance Report:"
    echo "  $RESULTS_DIR/simple-performance-report-${TIMESTAMP}.md"
    echo ""
    
    echo "To view results:"
    echo "  cat $RESULTS_DIR/simple-performance-report-${TIMESTAMP}.md"
    echo "  less $RESULTS_DIR/simple-performance-report-${TIMESTAMP}.md"
}

# Main test function
run_simple_load_tests() {
    log "Starting simple load testing..."
    
    create_results_dir
    check_prerequisites
    get_blog_url
    
    # Run all tests
    test_connectivity
    run_simple_load_test
    run_stress_test
    test_response_time_under_load
    
    # Generate report
    generate_simple_performance_report
    
    success "All simple load tests completed!"
    show_simple_test_summary
}

# Main script logic
case "${1:-}" in
    "test")
        run_simple_load_tests
        ;;
    "connectivity")
        create_results_dir
        check_prerequisites
        get_blog_url
        test_connectivity
        ;;
    "load")
        create_results_dir
        check_prerequisites
        get_blog_url
        run_simple_load_test
        ;;
    "stress")
        create_results_dir
        check_prerequisites
        get_blog_url
        run_stress_test
        ;;
    "response-time")
        create_results_dir
        check_prerequisites
        get_blog_url
        test_response_time_under_load
        ;;
    "check")
        check_prerequisites
        ;;
    "help"|"-h"|"--help")
        echo "Simple Blog Load Testing Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  test           - Run all simple load tests (default)"
        echo "  connectivity   - Test basic connectivity only"
        echo "  load           - Run simple load test only"
        echo "  stress         - Run stress test only"
        echo "  response-time  - Test response time under load only"
        echo "  check          - Check prerequisites only"
        echo "  help           - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  BLOG_URL              - Blog URL to test"
        echo "  TEST_DURATION         - Test duration in seconds (default: 30)"
        echo "  CONCURRENT_USERS      - Number of concurrent users (default: 5)"
        echo "  REQUESTS_PER_USER     - Requests per user (default: 20)"
        echo ""
        echo "Examples:"
        echo "  $0 test                                    # Run all tests"
        echo "  $0 connectivity                            # Test connectivity only"
        echo "  $0 load                                    # Run simple load test"
        echo "  BLOG_URL=https://myblog.com $0 test       # Test specific URL"
        echo "  TEST_DURATION=60 $0 test                  # Run tests for 1 minute"
        echo ""
        echo "Prerequisites:"
        echo "  - curl (usually pre-installed)"
        echo ""
        echo "Results:"
        echo "  All test results are saved in the 'simple-load-test-results' directory"
        echo "  A comprehensive performance report is generated in Markdown format"
        ;;
    *)
        echo "Simple Blog Load Testing Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 test        - Run all simple load tests"
        echo "  $0 check       - Check prerequisites"
        echo "  $0 help        - Show detailed help"
        ;;
esac
