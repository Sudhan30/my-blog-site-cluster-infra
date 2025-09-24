#!/bin/bash

# Quick HPA Test Script
# Simple one-liner commands to test HPA functionality

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
APP_LABEL="app=blog"
HPA_NAME="blog-hpa"
BLOG_URL="https://blog.sudharsana.dev"

# Function to show HPA status
show_hpa_status() {
    echo -e "${CYAN}=== HPA Status ===${NC}"
    kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    echo ""
    
    echo -e "${CYAN}=== Pod Status ===${NC}"
    kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide
    echo ""
    
    echo -e "${CYAN}=== Resource Usage ===${NC}"
    kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" 2>/dev/null || echo "Metrics not available"
    echo ""
}

# Function to generate load and monitor
generate_load_and_monitor() {
    local duration="${1:-300}"  # 5 minutes default
    local concurrent_users="${2:-200}"
    
    echo -e "${BLUE}Starting load test for ${duration} seconds with ${concurrent_users} concurrent users...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
    echo ""
    
    # Show initial status
    show_hpa_status
    
    # Start load generation in background
    echo -e "${GREEN}Generating load...${NC}"
    hey -z "${duration}s" -c "$concurrent_users" "$BLOG_URL" > /dev/null 2>&1 &
    local load_pid=$!
    
    # Monitor HPA in real-time
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ] && kill -0 $load_pid 2>/dev/null; do
        echo -e "${CYAN}=== $(date) ===${NC}"
        
        # Show HPA status
        kubectl get hpa -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | while read line; do
            echo "HPA: $line"
        done
        
        # Show pod count
        local pod_count=$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers | wc -l)
        echo "Pods: $pod_count"
        
        # Show resource usage
        kubectl top pods -n "$NAMESPACE" -l "$APP_LABEL" --no-headers 2>/dev/null | head -3 | while read line; do
            echo "$line"
        done
        
        echo ""
        sleep 30
    done
    
    # Wait for load generation to complete
    wait $load_pid 2>/dev/null || true
    
    echo -e "${GREEN}Load test completed!${NC}"
    echo ""
    
    # Show final status
    show_hpa_status
    
    # Show HPA events
    echo -e "${CYAN}=== HPA Events ===${NC}"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$HPA_NAME" --sort-by='.lastTimestamp' | tail -10
}

# Function to show help
show_help() {
    echo "Quick HPA Test Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status                    - Show current HPA status"
    echo "  test [duration] [users]   - Generate load and monitor HPA (default: 300s, 200 users)"
    echo "  load [duration] [users]   - Same as test"
    echo "  monitor                   - Monitor HPA in real-time"
    echo "  events                    - Show HPA events"
    echo "  help                      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status                 # Show current status"
    echo "  $0 test                   # Run 5-minute load test with 200 users"
    echo "  $0 test 600 100           # Run 10-minute load test with 100 users"
    echo "  $0 monitor                # Monitor HPA in real-time"
    echo "  $0 events                 # Show HPA events"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE                 - Kubernetes namespace (default: web)"
    echo "  APP_LABEL                 - App label selector (default: app=blog)"
    echo "  HPA_NAME                  - HPA name (default: blog-hpa)"
    echo "  BLOG_URL                  - Blog URL to test (default: https://blog.sudharsana.dev)"
}

# Function to monitor HPA in real-time
monitor_hpa() {
    echo -e "${BLUE}Monitoring HPA in real-time...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}=== HPA Monitor - $(date) ===${NC}"
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
        
        sleep 10
    done
}

# Function to show HPA events
show_hpa_events() {
    echo -e "${CYAN}=== HPA Events ===${NC}"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$HPA_NAME" --sort-by='.lastTimestamp' | tail -20
    echo ""
    
    echo -e "${CYAN}=== Scaling Events ===${NC}"
    kubectl get events -n "$NAMESPACE" --field-selector reason=SuccessfulRescale --sort-by='.lastTimestamp' | tail -10
}

# Main script logic
case "${1:-}" in
    "status")
        show_hpa_status
        ;;
    "test"|"load")
        generate_load_and_monitor "$2" "$3"
        ;;
    "monitor")
        monitor_hpa
        ;;
    "events")
        show_hpa_events
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Quick HPA Test Script"
        echo ""
        echo "Usage: $0 [command] [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 status    - Show current HPA status"
        echo "  $0 test      - Run load test and monitor HPA"
        echo "  $0 monitor   - Monitor HPA in real-time"
        echo "  $0 events    - Show HPA events"
        ;;
esac
