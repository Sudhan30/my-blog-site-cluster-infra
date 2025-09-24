#!/bin/bash

# Blog Site Load Testing Script
# This script performs comprehensive load testing on your blog site

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
BLOG_DOMAIN=""
TEST_DURATION=60
CONCURRENT_USERS=10
REQUESTS_PER_SECOND=5
TEST_TYPE="basic"

# Results directory
RESULTS_DIR="load-test-results"
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
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    # Check for ab (Apache Bench)
    if ! command -v ab &> /dev/null; then
        missing_tools+=("apache2-utils")
    fi
    
    # Check for wrk
    if ! command -v wrk &> /dev/null; then
        missing_tools+=("wrk")
    fi
    
    # Check for siege
    if ! command -v siege &> /dev/null; then
        missing_tools+=("siege")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        warning "Missing tools: ${missing_tools[*]}"
        echo "Install missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                "curl")
                    echo "  - curl: Usually pre-installed"
                    ;;
                "apache2-utils")
                    echo "  - apache2-utils: sudo apt-get install apache2-utils (Ubuntu/Debian)"
                    echo "  - httpd-tools: sudo yum install httpd-tools (CentOS/RHEL)"
                    echo "  - brew install httpd (macOS)"
                    ;;
                "wrk")
                    echo "  - wrk: sudo apt-get install wrk (Ubuntu/Debian)"
                    echo "  - brew install wrk (macOS)"
                    echo "  - Or compile from source: https://github.com/wg/wrk"
                    ;;
                "siege")
                    echo "  - siege: sudo apt-get install siege (Ubuntu/Debian)"
                    echo "  - brew install siege (macOS)"
                    ;;
            esac
        done
        echo ""
        echo "Some tests will be skipped if tools are missing."
        echo "Press Enter to continue or Ctrl+C to exit..."
        read -r
    else
        success "All prerequisites found"
    fi
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
        
        # Extract domain from URL
        BLOG_DOMAIN=$(echo "$BLOG_URL" | sed -E 's|https?://([^/]+).*|\1|')
        
        log "Blog URL: $BLOG_URL"
        log "Blog Domain: $BLOG_DOMAIN"
    fi
}

# Function to test basic connectivity
test_connectivity() {
    log "Testing basic connectivity..."
    
    local result_file="$RESULTS_DIR/connectivity-test-${TIMESTAMP}.txt"
    
    echo "# Connectivity Test Results" > "$result_file"
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
    
    # Test DNS resolution
    echo "" >> "$result_file"
    echo "## DNS Resolution Test" >> "$result_file"
    if nslookup "$BLOG_DOMAIN" >> "$result_file" 2>&1; then
        success "DNS resolution test completed"
    else
        warning "DNS resolution test failed"
    fi
    
    # Test SSL certificate (if HTTPS)
    if [[ "$BLOG_URL" == https://* ]]; then
        echo "" >> "$result_file"
        echo "## SSL Certificate Test" >> "$result_file"
        if openssl s_client -connect "$BLOG_DOMAIN:443" -servername "$BLOG_DOMAIN" < /dev/null 2>/dev/null | openssl x509 -noout -dates >> "$result_file" 2>&1; then
            success "SSL certificate test completed"
        else
            warning "SSL certificate test failed"
        fi
    fi
    
    success "Connectivity test results saved to $result_file"
}

# Function to run Apache Bench test
run_apache_bench_test() {
    if ! command -v ab &> /dev/null; then
        warning "Apache Bench (ab) not found, skipping Apache Bench test"
        return 0
    fi
    
    log "Running Apache Bench load test..."
    
    local result_file="$RESULTS_DIR/apache-bench-test-${TIMESTAMP}.txt"
    local requests=1000
    local concurrency=10
    
    echo "# Apache Bench Load Test Results" > "$result_file"
    echo "# Tested: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "# Requests: $requests" >> "$result_file"
    echo "# Concurrency: $concurrency" >> "$result_file"
    echo "" >> "$result_file"
    
    if ab -n "$requests" -c "$concurrency" -g "$RESULTS_DIR/ab-graph-${TIMESTAMP}.dat" "$BLOG_URL" >> "$result_file" 2>&1; then
        success "Apache Bench test completed"
        
        # Extract key metrics
        local rps=$(grep "Requests per second" "$result_file" | awk '{print $4}')
        local avg_time=$(grep "Time per request.*mean)" "$result_file" | awk '{print $4}')
        local failed_requests=$(grep "Failed requests" "$result_file" | awk '{print $3}')
        
        highlight "Apache Bench Results:"
        echo "  Requests per second: $rps"
        echo "  Average response time: $avg_time ms"
        echo "  Failed requests: $failed_requests"
        
        success "Apache Bench results saved to $result_file"
    else
        error "Apache Bench test failed"
    fi
}

# Function to run wrk test
run_wrk_test() {
    if ! command -v wrk &> /dev/null; then
        warning "wrk not found, skipping wrk test"
        return 0
    fi
    
    log "Running wrk load test..."
    
    local result_file="$RESULTS_DIR/wrk-test-${TIMESTAMP}.txt"
    local duration="${TEST_DURATION}s"
    local threads=4
    local connections=10
    
    echo "# wrk Load Test Results" > "$result_file"
    echo "# Tested: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "# Duration: $duration" >> "$result_file"
    echo "# Threads: $threads" >> "$result_file"
    echo "# Connections: $connections" >> "$result_file"
    echo "" >> "$result_file"
    
    if wrk -t"$threads" -c"$connections" -d"$duration" --latency "$BLOG_URL" >> "$result_file" 2>&1; then
        success "wrk test completed"
        
        # Extract key metrics
        local rps=$(grep "Requests/sec" "$result_file" | awk '{print $2}')
        local avg_latency=$(grep "Latency" "$result_file" | awk '{print $2}')
        local max_latency=$(grep "Latency" "$result_file" | awk '{print $4}')
        
        highlight "wrk Results:"
        echo "  Requests per second: $rps"
        echo "  Average latency: $avg_latency"
        echo "  Max latency: $max_latency"
        
        success "wrk results saved to $result_file"
    else
        error "wrk test failed"
    fi
}

# Function to run siege test
run_siege_test() {
    if ! command -v siege &> /dev/null; then
        warning "siege not found, skipping siege test"
        return 0
    fi
    
    log "Running siege load test..."
    
    local result_file="$RESULTS_DIR/siege-test-${TIMESTAMP}.txt"
    local duration="${TEST_DURATION}s"
    local concurrent_users=10
    
    echo "# siege Load Test Results" > "$result_file"
    echo "# Tested: $(date)" >> "$result_file"
    echo "# URL: $BLOG_URL" >> "$result_file"
    echo "# Duration: $duration" >> "$result_file"
    echo "# Concurrent users: $concurrent_users" >> "$result_file"
    echo "" >> "$result_file"
    
    if siege -c"$concurrent_users" -t"$duration" -q "$BLOG_URL" >> "$result_file" 2>&1; then
        success "siege test completed"
        
        # Extract key metrics
        local rps=$(grep "Transaction rate" "$result_file" | awk '{print $3}')
        local avg_time=$(grep "Response time" "$result_file" | awk '{print $3}')
        local failed_transactions=$(grep "Failed transactions" "$result_file" | awk '{print $3}')
        
        highlight "siege Results:"
        echo "  Transaction rate: $rps trans/sec"
        echo "  Response time: $avg_time secs"
        echo "  Failed transactions: $failed_transactions"
        
        success "siege results saved to $result_file"
    else
        error "siege test failed"
    fi
}

# Function to run custom curl-based test
run_curl_test() {
    log "Running custom curl-based load test..."
    
    local result_file="$RESULTS_DIR/curl-test-${TIMESTAMP}.txt"
    local total_requests=100
    local concurrent_requests=5
    
    echo "# Custom curl Load Test Results" > "$result_file"
    echo "# Tested: $(date)" >> "$result_file"
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
    
    highlight "Custom curl Results:"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $success_count"
    echo "  Success rate: $success_rate%"
    echo "  Average response time: ${avg_time}s"
    echo "  Min response time: ${min_time}s"
    echo "  Max response time: ${max_time}s"
    
    success "Custom curl test completed"
    success "curl results saved to $result_file"
}

# Function to run stress test
run_stress_test() {
    log "Running stress test with high load..."
    
    local result_file="$RESULTS_DIR/stress-test-${TIMESTAMP}.txt"
    local duration=30
    local concurrent_users=50
    
    echo "# Stress Test Results" > "$result_file"
    echo "# Tested: $(date)" >> "$result_file"
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
    success "Stress test results saved to $result_file"
}

# Function to generate performance report
generate_performance_report() {
    log "Generating performance report..."
    
    local report_file="$RESULTS_DIR/performance-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# Blog Site Performance Report

**Generated:** $(date)  
**Blog URL:** $BLOG_URL  
**Test Duration:** $TEST_DURATION seconds  
**Concurrent Users:** $CONCURRENT_USERS  

## Test Summary

This report contains the results of comprehensive load testing performed on your blog site.

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

## Performance Recommendations

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
*Report generated by load-test-blog.sh*
EOF
    
    success "Performance report generated: $report_file"
}

# Function to show test results summary
show_test_summary() {
    echo ""
    highlight "Load Test Summary"
    echo "=================="
    echo "Blog URL: $BLOG_URL"
    echo "Test Duration: $TEST_DURATION seconds"
    echo "Concurrent Users: $CONCURRENT_USERS"
    echo "Results Directory: $RESULTS_DIR"
    echo ""
    
    echo "Test Results:"
    ls -la "$RESULTS_DIR"/*-${TIMESTAMP}.* 2>/dev/null || echo "No test results found"
    echo ""
    
    echo "Performance Report:"
    echo "  $RESULTS_DIR/performance-report-${TIMESTAMP}.md"
    echo ""
    
    echo "To view results:"
    echo "  cat $RESULTS_DIR/performance-report-${TIMESTAMP}.md"
    echo "  less $RESULTS_DIR/performance-report-${TIMESTAMP}.md"
}

# Main test function
run_load_tests() {
    log "Starting comprehensive load testing..."
    
    create_results_dir
    get_blog_url
    
    # Run all tests
    test_connectivity
    run_apache_bench_test
    run_wrk_test
    run_siege_test
    run_curl_test
    run_stress_test
    
    # Generate report
    generate_performance_report
    
    success "All load tests completed!"
    show_test_summary
}

# Main script logic
case "${1:-}" in
    "test")
        run_load_tests
        ;;
    "connectivity")
        create_results_dir
        get_blog_url
        test_connectivity
        ;;
    "apache-bench")
        create_results_dir
        get_blog_url
        run_apache_bench_test
        ;;
    "wrk")
        create_results_dir
        get_blog_url
        run_wrk_test
        ;;
    "siege")
        create_results_dir
        get_blog_url
        run_siege_test
        ;;
    "curl")
        create_results_dir
        get_blog_url
        run_curl_test
        ;;
    "stress")
        create_results_dir
        get_blog_url
        run_stress_test
        ;;
    "check")
        check_prerequisites
        ;;
    "help"|"-h"|"--help")
        echo "Blog Site Load Testing Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  test           - Run all load tests (default)"
        echo "  connectivity   - Test basic connectivity only"
        echo "  apache-bench   - Run Apache Bench test only"
        echo "  wrk            - Run wrk test only"
        echo "  siege          - Run siege test only"
        echo "  curl           - Run custom curl test only"
        echo "  stress         - Run stress test only"
        echo "  check          - Check prerequisites only"
        echo "  help           - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  BLOG_URL              - Blog URL to test"
        echo "  TEST_DURATION         - Test duration in seconds (default: 60)"
        echo "  CONCURRENT_USERS      - Number of concurrent users (default: 10)"
        echo "  REQUESTS_PER_SECOND   - Requests per second (default: 5)"
        echo ""
        echo "Examples:"
        echo "  $0 test                                    # Run all tests"
        echo "  $0 connectivity                            # Test connectivity only"
        echo "  $0 apache-bench                            # Run Apache Bench test"
        echo "  BLOG_URL=https://myblog.com $0 test       # Test specific URL"
        echo "  TEST_DURATION=120 $0 test                 # Run tests for 2 minutes"
        echo ""
        echo "Prerequisites:"
        echo "  - curl (usually pre-installed)"
        echo "  - apache2-utils (for ab command)"
        echo "  - wrk (optional, for advanced testing)"
        echo "  - siege (optional, for advanced testing)"
        echo ""
        echo "Results:"
        echo "  All test results are saved in the 'load-test-results' directory"
        echo "  A comprehensive performance report is generated in Markdown format"
        ;;
    *)
        echo "Blog Site Load Testing Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 test        - Run all load tests"
        echo "  $0 check       - Check prerequisites"
        echo "  $0 help        - Show detailed help"
        ;;
esac
