#!/bin/bash

# Server Cron Jobs Backup and Restore Script
# This script backs up and restores cron jobs for disaster recovery

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to backup current cron jobs
backup_cron() {
    local backup_file="server-cron-jobs-$(date +%Y%m%d-%H%M%S).txt"
    
    log "Backing up current cron jobs to $backup_file..."
    
    if crontab -l > "$backup_file" 2>/dev/null; then
        success "Cron jobs backed up to $backup_file"
        echo "Backup file: $backup_file"
        echo "Contents:"
        echo "----------------------------------------"
        cat "$backup_file"
        echo "----------------------------------------"
    else
        error "Failed to backup cron jobs"
        return 1
    fi
}

# Function to restore cron jobs from file
restore_cron() {
    local restore_file="$1"
    
    if [ -z "$restore_file" ]; then
        error "Please specify a restore file"
        echo "Usage: $0 restore <backup-file>"
        return 1
    fi
    
    if [ ! -f "$restore_file" ]; then
        error "Restore file $restore_file not found"
        return 1
    fi
    
    log "Restoring cron jobs from $restore_file..."
    
    # Create a backup before restoring
    local current_backup="cron-backup-before-restore-$(date +%Y%m%d-%H%M%S).txt"
    crontab -l > "$current_backup" 2>/dev/null || true
    
    if crontab "$restore_file"; then
        success "Cron jobs restored from $restore_file"
        log "Previous cron jobs backed up to $current_backup"
    else
        error "Failed to restore cron jobs"
        return 1
    fi
}

# Function to show current cron jobs
show_cron() {
    log "Current cron jobs:"
    echo "----------------------------------------"
    if crontab -l 2>/dev/null; then
        echo "----------------------------------------"
    else
        warning "No cron jobs found or unable to read crontab"
    fi
}

# Function to create the standard server cron jobs
create_standard_cron() {
    local cron_file="server-standard-cron.txt"
    
    log "Creating standard server cron jobs file..."
    
    cat > "$cron_file" << 'EOF'
# Standard Server Cron Jobs
# m h  dom mon dow   command

# DuckDNS update - runs every 5 minutes
*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1

# SSL Certificate renewal - runs daily at 8:45 AM
45 8 * * * "/home/sudhan0312/.acme.sh"/acme.sh --cron --home "/home/sudhan0312/.acme.sh" > /dev/null

# Log management - runs every 2 hours
0 */2 * * * /tmp/log-cleanup.sh >> /tmp/log-cleanup.log 2>&1

# Logrotate - runs daily at 3 AM
0 3 * * * /usr/sbin/logrotate /etc/logrotate.d/monitoring-logs >> /tmp/log-cleanup.log 2>&1

# Weekly deep cleanup - runs every Sunday at 4 AM
0 4 * * 0 /tmp/log-cleanup.sh --deep >> /tmp/log-cleanup.log 2>&1

# Log monitoring - runs every hour
0 * * * * /tmp/log-monitor.sh >> /tmp/log-monitor.log 2>&1

# GitOps automation - runs every 5 minutes (if automation is set up)
# */5 * * * * /tmp/flux-reconcile.sh >> /tmp/flux-reconcile.log 2>&1

# Deployment monitoring - runs every 10 minutes (if automation is set up)
# */10 * * * * /tmp/deployment-monitor.sh >> /tmp/deployment-monitor.log 2>&1
EOF

    success "Standard server cron jobs created in $cron_file"
    echo "File contents:"
    echo "----------------------------------------"
    cat "$cron_file"
    echo "----------------------------------------"
}

# Function to install standard cron jobs
install_standard_cron() {
    local cron_file="server-standard-cron.txt"
    
    if [ ! -f "$cron_file" ]; then
        error "Standard cron file $cron_file not found"
        echo "Run '$0 create' first to create the standard cron file"
        return 1
    fi
    
    log "Installing standard server cron jobs..."
    
    # Create a backup before installing
    local backup_file="cron-backup-before-install-$(date +%Y%m%d-%H%M%S).txt"
    crontab -l > "$backup_file" 2>/dev/null || true
    
    if crontab "$cron_file"; then
        success "Standard cron jobs installed successfully"
        log "Previous cron jobs backed up to $backup_file"
        show_cron
    else
        error "Failed to install standard cron jobs"
        return 1
    fi
}

# Function to validate cron syntax
validate_cron() {
    local cron_file="$1"
    
    if [ -z "$cron_file" ]; then
        error "Please specify a cron file to validate"
        return 1
    fi
    
    if [ ! -f "$cron_file" ]; then
        error "Cron file $cron_file not found"
        return 1
    fi
    
    log "Validating cron syntax in $cron_file..."
    
    # Check each line for basic cron syntax
    local line_num=0
    local has_errors=false
    
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Check if line has 6 fields (minute hour day month dayofweek command)
        local field_count=$(echo "$line" | awk '{print NF}')
        if [ "$field_count" -lt 6 ]; then
            error "Line $line_num: Invalid cron syntax (too few fields): $line"
            has_errors=true
        fi
    done < "$cron_file"
    
    if [ "$has_errors" = false ]; then
        success "Cron syntax validation passed"
    else
        error "Cron syntax validation failed"
        return 1
    fi
}

# Main script logic
case "${1:-}" in
    "backup")
        backup_cron
        ;;
    "restore")
        restore_cron "$2"
        ;;
    "show")
        show_cron
        ;;
    "create")
        create_standard_cron
        ;;
    "install")
        install_standard_cron
        ;;
    "validate")
        validate_cron "$2"
        ;;
    "help"|"-h"|"--help")
        echo "Server Cron Jobs Backup and Restore Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  backup                    - Backup current cron jobs to timestamped file"
        echo "  restore <backup-file>     - Restore cron jobs from backup file"
        echo "  show                      - Show current cron jobs"
        echo "  create                    - Create standard server cron jobs file"
        echo "  install                   - Install standard server cron jobs"
        echo "  validate <cron-file>      - Validate cron syntax in file"
        echo "  help                      - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 backup                                    # Backup current cron jobs"
        echo "  $0 restore server-cron-jobs-20250108-123456.txt  # Restore from backup"
        echo "  $0 show                                      # Show current cron jobs"
        echo "  $0 create                                    # Create standard cron file"
        echo "  $0 install                                   # Install standard cron jobs"
        echo "  $0 validate server-standard-cron.txt        # Validate cron syntax"
        ;;
    *)
        echo "Server Cron Jobs Backup and Restore Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 backup    - Backup current cron jobs"
        echo "  $0 show      - Show current cron jobs"
        echo "  $0 create    - Create standard server cron jobs"
        echo "  $0 install   - Install standard server cron jobs"
        ;;
esac
