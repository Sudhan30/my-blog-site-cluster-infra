#!/bin/bash

# Backend Stack Setup Script
# This script sets up the complete backend infrastructure for the blog

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
BACKEND_APP="blog-backend"
MONITORING_APP="monitoring"

# Function to show help
show_help() {
    echo "Backend Stack Setup Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup                    - Set up complete backend stack"
    echo "  backend                  - Set up backend only"
    echo "  monitoring               - Set up monitoring only"
    echo "  docker-compose           - Start with Docker Compose"
    echo "  status                   - Show status of all components"
    echo "  logs [component]         - Show logs for component"
    echo "  test                     - Test backend functionality"
    echo "  cleanup                  - Clean up all components"
    echo "  help                     - Show this help message"
    echo ""
    echo "Components:"
    echo "  backend                  - Blog backend API"
    echo "  postgres                 - PostgreSQL database"
    echo "  prometheus               - Prometheus metrics"
    echo "  grafana                  - Grafana dashboards"
    echo "  postgres-exporter        - PostgreSQL metrics exporter"
    echo "  blackbox-exporter        - HTTP uptime monitoring"
    echo ""
    echo "Examples:"
    echo "  $0 setup                 # Set up complete stack"
    echo "  $0 backend               # Set up backend only"
    echo "  $0 docker-compose        # Start with Docker Compose"
    echo "  $0 status                # Show status"
    echo "  $0 logs backend          # Show backend logs"
    echo "  $0 test                  # Test backend"
    echo ""
}

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
    
    if ! command -v docker &> /dev/null; then
        warning "Docker is not installed - Docker Compose option will not work"
    fi
    
    success "Prerequisites check passed"
}

# Function to create namespace
create_namespace() {
    log "Creating namespace '$NAMESPACE'..."
    
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        info "Namespace '$NAMESPACE' already exists"
    else
        kubectl create namespace "$NAMESPACE"
        success "Namespace '$NAMESPACE' created"
    fi
}

# Function to set up backend
setup_backend() {
    log "Setting up backend components..."
    
    # Apply backend manifests
    kubectl apply -k clusters/prod/apps/backend/
    
    # Wait for backend to be ready
    log "Waiting for backend to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/blog-backend -n "$NAMESPACE"
    
    # Wait for postgres to be ready
    log "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/postgres -n "$NAMESPACE"
    
    success "Backend setup completed"
}

# Function to set up monitoring
setup_monitoring() {
    log "Setting up monitoring components..."
    
    # Apply monitoring manifests
    kubectl apply -k clusters/prod/apps/monitoring/
    
    # Wait for monitoring components to be ready
    log "Waiting for monitoring components to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/postgres-exporter -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/blackbox-exporter -n "$NAMESPACE"
    
    success "Monitoring setup completed"
}

# Function to set up complete stack
setup_complete_stack() {
    log "Setting up complete backend stack..."
    
    check_prerequisites
    create_namespace
    setup_backend
    setup_monitoring
    
    success "Complete backend stack setup completed!"
    
    echo ""
    highlight "=== Access Information ==="
    echo ""
    echo "Backend API:"
    echo "  URL: https://api.sudharsana.dev"
    echo "  Health: https://api.sudharsana.dev/health"
    echo "  Metrics: https://api.sudharsana.dev/metrics"
    echo ""
    echo "Monitoring:"
    echo "  Grafana: https://grafana.sudharsana.dev (admin/admin123)"
    echo "  Prometheus: https://prometheus.sudharsana.dev"
    echo ""
    echo "Database:"
    echo "  Host: postgres-service.web.svc.cluster.local"
    echo "  Port: 5432"
    echo "  Database: blog_db"
    echo "  User: blog_user"
    echo "  Password: blog_password"
    echo ""
}

# Function to start with Docker Compose
start_docker_compose() {
    log "Starting backend stack with Docker Compose..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is required for Docker Compose"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is required"
        exit 1
    fi
    
    # Create logs directory
    mkdir -p logs
    
    # Start services
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    success "Backend stack started with Docker Compose"
    
    echo ""
    highlight "=== Access Information ==="
    echo ""
    echo "Backend API: http://localhost:3001"
    echo "Grafana: http://localhost:3000 (admin/admin123)"
    echo "Prometheus: http://localhost:9090"
    echo "PostgreSQL: localhost:5432"
    echo "Redis: localhost:6379"
    echo ""
}

# Function to show status
show_status() {
    log "Showing status of backend components..."
    
    echo ""
    highlight "=== Backend Status ==="
    kubectl get pods -n "$NAMESPACE" -l app=blog-backend
    kubectl get pods -n "$NAMESPACE" -l app=postgres
    
    echo ""
    highlight "=== Monitoring Status ==="
    kubectl get pods -n "$NAMESPACE" -l app=prometheus
    kubectl get pods -n "$NAMESPACE" -l app=grafana
    kubectl get pods -n "$NAMESPACE" -l app=postgres-exporter
    kubectl get pods -n "$NAMESPACE" -l app=blackbox-exporter
    
    echo ""
    highlight "=== Services ==="
    kubectl get svc -n "$NAMESPACE"
    
    echo ""
    highlight "=== Ingress ==="
    kubectl get ingress -n "$NAMESPACE"
    
    echo ""
    highlight "=== Persistent Volumes ==="
    kubectl get pvc -n "$NAMESPACE"
}

# Function to show logs
show_logs() {
    local component="${1:-backend}"
    
    log "Showing logs for $component..."
    
    case "$component" in
        "backend")
            kubectl logs -n "$NAMESPACE" -l app=blog-backend --tail=100
            ;;
        "postgres")
            kubectl logs -n "$NAMESPACE" -l app=postgres --tail=100
            ;;
        "prometheus")
            kubectl logs -n "$NAMESPACE" -l app=prometheus --tail=100
            ;;
        "grafana")
            kubectl logs -n "$NAMESPACE" -l app=grafana --tail=100
            ;;
        "postgres-exporter")
            kubectl logs -n "$NAMESPACE" -l app=postgres-exporter --tail=100
            ;;
        "blackbox-exporter")
            kubectl logs -n "$NAMESPACE" -l app=blackbox-exporter --tail=100
            ;;
        *)
            error "Unknown component: $component"
            echo "Available components: backend, postgres, prometheus, grafana, postgres-exporter, blackbox-exporter"
            exit 1
            ;;
    esac
}

# Function to test backend
test_backend() {
    log "Testing backend functionality..."
    
    # Get backend service URL
    local backend_url="https://api.sudharsana.dev"
    
    echo ""
    highlight "=== Testing Backend API ==="
    
    # Test health endpoint
    echo "Testing health endpoint..."
    if curl -s -f "$backend_url/health" > /dev/null; then
        success "Health endpoint is working"
    else
        error "Health endpoint is not working"
    fi
    
    # Test metrics endpoint
    echo "Testing metrics endpoint..."
    if curl -s -f "$backend_url/metrics" > /dev/null; then
        success "Metrics endpoint is working"
    else
        error "Metrics endpoint is not working"
    fi
    
    # Test likes endpoint
    echo "Testing likes endpoint..."
    if curl -s -f "$backend_url/api/posts/test-post/likes" > /dev/null; then
        success "Likes endpoint is working"
    else
        error "Likes endpoint is not working"
    fi
    
    # Test comments endpoint
    echo "Testing comments endpoint..."
    if curl -s -f "$backend_url/api/posts/test-post/comments" > /dev/null; then
        success "Comments endpoint is working"
    else
        error "Comments endpoint is not working"
    fi
    
    # Test analytics endpoint
    echo "Testing analytics endpoint..."
    if curl -s -f "$backend_url/api/analytics" > /dev/null; then
        success "Analytics endpoint is working"
    else
        error "Analytics endpoint is not working"
    fi
    
    echo ""
    highlight "=== Testing Monitoring ==="
    
    # Test Prometheus
    echo "Testing Prometheus..."
    if curl -s -f "https://prometheus.sudharsana.dev" > /dev/null; then
        success "Prometheus is accessible"
    else
        error "Prometheus is not accessible"
    fi
    
    # Test Grafana
    echo "Testing Grafana..."
    if curl -s -f "https://grafana.sudharsana.dev" > /dev/null; then
        success "Grafana is accessible"
    else
        error "Grafana is not accessible"
    fi
    
    success "Backend testing completed!"
}

# Function to cleanup
cleanup() {
    log "Cleaning up backend components..."
    
    # Delete monitoring components
    kubectl delete -k clusters/prod/apps/monitoring/ --ignore-not-found=true
    
    # Delete backend components
    kubectl delete -k clusters/prod/apps/backend/ --ignore-not-found=true
    
    # Stop Docker Compose if running
    if [ -f "docker-compose.yml" ]; then
        if command -v docker-compose &> /dev/null; then
            docker-compose down
        else
            docker compose down
        fi
    fi
    
    success "Cleanup completed"
}

# Main script logic
case "${1:-}" in
    "setup")
        setup_complete_stack
        ;;
    "backend")
        check_prerequisites
        create_namespace
        setup_backend
        ;;
    "monitoring")
        check_prerequisites
        create_namespace
        setup_monitoring
        ;;
    "docker-compose")
        start_docker_compose
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "test")
        test_backend
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Backend Stack Setup Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 setup                 # Set up complete stack"
        echo "  $0 backend               # Set up backend only"
        echo "  $0 docker-compose        # Start with Docker Compose"
        echo "  $0 status                # Show status"
        echo "  $0 test                  # Test backend"
        echo "  $0 help                  # Show detailed help"
        ;;
esac
