#!/bin/bash

# Backend API Testing Script
# This script tests the backend API functionality

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
BACKEND_URL="https://api.sudharsana.dev"
TEST_POST_ID="test-post-$(date +%s)"

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

# Function to test endpoint
test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="${4:-200}"
    
    local url="$BACKEND_URL$endpoint"
    local response
    local status_code
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$url")
        status_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | head -n -1)
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url")
        status_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | head -n -1)
    fi
    
    if [ "$status_code" -eq "$expected_status" ]; then
        success "$method $endpoint - Status: $status_code"
        if [ -n "$response_body" ]; then
            echo "  Response: $response_body"
        fi
        return 0
    else
        error "$method $endpoint - Expected: $expected_status, Got: $status_code"
        if [ -n "$response_body" ]; then
            echo "  Response: $response_body"
        fi
        return 1
    fi
}

# Function to test health endpoints
test_health_endpoints() {
    log "Testing health endpoints..."
    
    test_endpoint "GET" "/health"
    test_endpoint "GET" "/ready"
    test_endpoint "GET" "/metrics"
}

# Function to test likes functionality
test_likes_functionality() {
    log "Testing likes functionality..."
    
    # Get initial likes count
    test_endpoint "GET" "/api/posts/$TEST_POST_ID/likes"
    
    # Like the post
    local like_data='{"userId":"test-user-123","userIP":"192.168.1.100"}'
    test_endpoint "POST" "/api/posts/$TEST_POST_ID/like" "$like_data"
    
    # Get likes count again
    test_endpoint "GET" "/api/posts/$TEST_POST_ID/likes"
    
    # Try to like again (should fail)
    test_endpoint "POST" "/api/posts/$TEST_POST_ID/like" "$like_data" "400"
    
    # Like with different user
    local like_data2='{"userId":"test-user-456","userIP":"192.168.1.101"}'
    test_endpoint "POST" "/api/posts/$TEST_POST_ID/like" "$like_data2"
    
    # Get final likes count
    test_endpoint "GET" "/api/posts/$TEST_POST_ID/likes"
}

# Function to test comments functionality
test_comments_functionality() {
    log "Testing comments functionality..."
    
    # Get initial comments
    test_endpoint "GET" "/api/posts/$TEST_POST_ID/comments"
    
    # Add a comment
    local comment_data='{"content":"This is a test comment","authorName":"Test User","authorEmail":"test@example.com"}'
    test_endpoint "POST" "/api/posts/$TEST_POST_ID/comments" "$comment_data"
    
    # Get comments again
    test_endpoint "GET" "/api/posts/$TEST_POST_ID/comments"
    
    # Add another comment
    local comment_data2='{"content":"This is another test comment","authorName":"Another User","authorEmail":"another@example.com"}'
    test_endpoint "POST" "/api/posts/$TEST_POST_ID/comments" "$comment_data2"
    
    # Get comments with pagination
    test_endpoint "GET" "/api/posts/$TEST_POST_ID/comments?page=1&limit=1"
    
    # Test invalid comment (missing content)
    local invalid_comment='{"authorName":"Test User"}'
    test_endpoint "POST" "/api/posts/$TEST_POST_ID/comments" "$invalid_comment" "400"
}

# Function to test analytics
test_analytics() {
    log "Testing analytics functionality..."
    
    # Get analytics for different periods
    test_endpoint "GET" "/api/analytics"
    test_endpoint "GET" "/api/analytics?period=1d"
    test_endpoint "GET" "/api/analytics?period=7d"
    test_endpoint "GET" "/api/analytics?period=30d"
    
    # Test invalid period
    test_endpoint "GET" "/api/analytics?period=invalid" "400"
}

# Function to test error handling
test_error_handling() {
    log "Testing error handling..."
    
    # Test 404
    test_endpoint "GET" "/api/nonexistent" "404"
    
    # Test invalid post ID
    test_endpoint "GET" "/api/posts//likes" "404"
    
    # Test invalid JSON
    echo '{"invalid": json}' | curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d @- "$BACKEND_URL/api/posts/$TEST_POST_ID/comments"
}

# Function to test rate limiting
test_rate_limiting() {
    log "Testing rate limiting..."
    
    local requests=0
    local rate_limited=false
    
    for i in {1..110}; do
        response=$(curl -s -w "\n%{http_code}" "$BACKEND_URL/health")
        status_code=$(echo "$response" | tail -n1)
        
        if [ "$status_code" -eq "429" ]; then
            rate_limited=true
            success "Rate limiting triggered after $requests requests"
            break
        fi
        
        requests=$((requests + 1))
    done
    
    if [ "$rate_limited" = false ]; then
        warning "Rate limiting not triggered after $requests requests"
    fi
}

# Function to run complete test suite
run_complete_test() {
    log "Running complete backend API test suite..."
    echo ""
    
    local test_results=()
    
    # Run tests
    test_health_endpoints && test_results+=("Health endpoints: PASS") || test_results+=("Health endpoints: FAIL")
    echo ""
    
    test_likes_functionality && test_results+=("Likes functionality: PASS") || test_results+=("Likes functionality: FAIL")
    echo ""
    
    test_comments_functionality && test_results+=("Comments functionality: PASS") || test_results+=("Comments functionality: FAIL")
    echo ""
    
    test_analytics && test_results+=("Analytics: PASS") || test_results+=("Analytics: FAIL")
    echo ""
    
    test_error_handling && test_results+=("Error handling: PASS") || test_results+=("Error handling: FAIL")
    echo ""
    
    test_rate_limiting && test_results+=("Rate limiting: PASS") || test_results+=("Rate limiting: FAIL")
    echo ""
    
    # Show results
    highlight "=== Test Results ==="
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            success "$result"
        else
            error "$result"
        fi
    done
    
    # Count results
    local pass_count=$(echo "${test_results[@]}" | grep -o "PASS" | wc -l)
    local fail_count=$(echo "${test_results[@]}" | grep -o "FAIL" | wc -l)
    
    echo ""
    highlight "=== Summary ==="
    echo "Total tests: $((pass_count + fail_count))"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    
    if [ "$fail_count" -eq 0 ]; then
        success "All tests passed! 🎉"
        return 0
    else
        error "Some tests failed. Please check the logs above."
        return 1
    fi
}

# Function to show help
show_help() {
    echo "Backend API Testing Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  test                    - Run complete test suite"
    echo "  health                  - Test health endpoints only"
    echo "  likes                   - Test likes functionality only"
    echo "  comments                - Test comments functionality only"
    echo "  analytics               - Test analytics functionality only"
    echo "  errors                  - Test error handling only"
    echo "  rate-limit              - Test rate limiting only"
    echo "  help                    - Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BACKEND_URL             - Backend API URL (default: https://api.sudharsana.dev)"
    echo ""
    echo "Examples:"
    echo "  $0 test                 # Run complete test suite"
    echo "  $0 health               # Test health endpoints"
    echo "  $0 likes                # Test likes functionality"
    echo "  BACKEND_URL=http://localhost:3001 $0 test  # Test local backend"
}

# Main script logic
case "${1:-}" in
    "test")
        run_complete_test
        ;;
    "health")
        test_health_endpoints
        ;;
    "likes")
        test_likes_functionality
        ;;
    "comments")
        test_comments_functionality
        ;;
    "analytics")
        test_analytics
        ;;
    "errors")
        test_error_handling
        ;;
    "rate-limit")
        test_rate_limiting
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Backend API Testing Script"
        echo ""
        echo "Usage: $0 [command]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 test        - Run complete test suite"
        echo "  $0 health      - Test health endpoints"
        echo "  $0 likes       - Test likes functionality"
        echo "  $0 comments    - Test comments functionality"
        echo "  $0 help        - Show detailed help"
        ;;
esac
