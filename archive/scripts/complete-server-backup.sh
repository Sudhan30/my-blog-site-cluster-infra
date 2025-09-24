#!/bin/bash

# Complete Server Backup Script
# This script backs up both cron jobs and server scripts for complete disaster recovery

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

# Server connection details
SERVER_USER="sudhan0312"
SERVER_HOST="suddu-um790-server"

# Timestamp for backups
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="complete-server-backup-${TIMESTAMP}"

# Function to create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log "Created backup directory: $BACKUP_DIR"
    fi
}

# Function to test SSH connection
test_ssh_connection() {
    log "Testing SSH connection to $SERVER_USER@$SERVER_HOST..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
        success "SSH connection successful"
        return 0
    else
        error "SSH connection failed"
        echo "Please ensure:"
        echo "1. SSH key is set up for passwordless access"
        echo "2. Server is accessible"
        echo "3. User has proper permissions"
        return 1
    fi
}

# Function to backup cron jobs
backup_cron_jobs() {
    log "Backing up cron jobs..."
    
    local cron_file="$BACKUP_DIR/server-cron-jobs-${TIMESTAMP}.txt"
    
    if ssh "$SERVER_USER@$SERVER_HOST" "crontab -l" > "$cron_file" 2>/dev/null; then
        success "Cron jobs backed up to $cron_file"
        
        # Show cron jobs
        echo "Current cron jobs:"
        echo "----------------------------------------"
        cat "$cron_file"
        echo "----------------------------------------"
        
        return 0
    else
        warning "Could not backup cron jobs (may not exist)"
        return 1
    fi
}

# Function to backup server scripts
backup_server_scripts() {
    log "Backing up server scripts..."
    
    local scripts_backed_up=0
    
    # Script paths and names
    declare -A scripts=(
        ["~/duckdns/duck.sh"]="duck.sh"
        ["/home/sudhan0312/.acme.sh/acme.sh"]="acme.sh"
        ["~/server_backup.sh"]="server_backup.sh"
    )
    
    for script_path in "${!scripts[@]}"; do
        local script_name="${scripts[$script_path]}"
        local backup_file="$BACKUP_DIR/${script_name}-${TIMESTAMP}.sh"
        
        log "Backing up $script_name from $script_path..."
        
        if ssh "$SERVER_USER@$SERVER_HOST" "test -f $script_path" 2>/dev/null; then
            if ssh "$SERVER_USER@$SERVER_HOST" "cat $script_path" > "$backup_file" 2>/dev/null; then
                success "Backed up $script_name"
                scripts_backed_up=$((scripts_backed_up + 1))
                
                # Show file info
                local file_size=$(wc -c < "$backup_file")
                local line_count=$(wc -l < "$backup_file")
                echo "  Size: $file_size bytes, Lines: $line_count"
            else
                warning "Failed to read $script_name"
            fi
        else
            warning "Script $script_name not found at $script_path"
        fi
    done
    
    success "Backed up $scripts_backed_up server scripts"
    return 0
}

# Function to backup system information
backup_system_info() {
    log "Backing up system information..."
    
    local system_info_file="$BACKUP_DIR/system-info-${TIMESTAMP}.txt"
    
    cat > "$system_info_file" << EOF
# Server System Information
# Backup created: $(date)
# Server: $SERVER_USER@$SERVER_HOST

## System Information:
EOF
    
    # Get system information via SSH
    ssh "$SERVER_USER@$SERVER_HOST" "uname -a" >> "$system_info_file" 2>/dev/null || echo "Could not get system info" >> "$system_info_file"
    
    echo "" >> "$system_info_file"
    echo "## Disk Usage:" >> "$system_info_file"
    ssh "$SERVER_USER@$SERVER_HOST" "df -h" >> "$system_info_file" 2>/dev/null || echo "Could not get disk usage" >> "$system_info_file"
    
    echo "" >> "$system_info_file"
    echo "## Memory Usage:" >> "$system_info_file"
    ssh "$SERVER_USER@$SERVER_HOST" "free -h" >> "$system_info_file" 2>/dev/null || echo "Could not get memory usage" >> "$system_info_file"
    
    echo "" >> "$system_info_file"
    echo "## Running Services:" >> "$system_info_file"
    ssh "$SERVER_USER@$SERVER_HOST" "systemctl list-units --type=service --state=running | head -20" >> "$system_info_file" 2>/dev/null || echo "Could not get running services" >> "$system_info_file"
    
    success "System information backed up to $system_info_file"
}

# Function to create restore script
create_restore_script() {
    log "Creating restore script..."
    
    local restore_script="$BACKUP_DIR/restore-server.sh"
    
    cat > "$restore_script" << 'EOF'
#!/bin/bash

# Server Restore Script
# This script restores server configuration from backup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Server connection details
SERVER_USER="sudhan0312"
SERVER_HOST="suddu-um790-server"

# Get backup timestamp from directory name
BACKUP_DIR=$(basename "$(pwd)")
TIMESTAMP=$(echo "$BACKUP_DIR" | grep -o '[0-9]\{8\}-[0-9]\{6\}')

if [ -z "$TIMESTAMP" ]; then
    error "Could not determine backup timestamp from directory name"
    exit 1
fi

log "Restoring server from backup: $BACKUP_DIR (timestamp: $TIMESTAMP)"

# Function to test SSH connection
test_ssh_connection() {
    log "Testing SSH connection to $SERVER_USER@$SERVER_HOST..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
        success "SSH connection successful"
        return 0
    else
        error "SSH connection failed"
        return 1
    fi
}

# Function to restore cron jobs
restore_cron_jobs() {
    local cron_file="server-cron-jobs-${TIMESTAMP}.txt"
    
    if [ ! -f "$cron_file" ]; then
        warning "Cron jobs file not found: $cron_file"
        return 1
    fi
    
    log "Restoring cron jobs from $cron_file..."
    
    # Create backup of current cron jobs
    local current_backup="cron-backup-before-restore-$(date +%Y%m%d-%H%M%S).txt"
    ssh "$SERVER_USER@$SERVER_HOST" "crontab -l > ~/$current_backup" 2>/dev/null || true
    
    # Restore cron jobs
    if scp "$cron_file" "$SERVER_USER@$SERVER_HOST:~/temp-cron.txt" 2>/dev/null; then
        if ssh "$SERVER_USER@$SERVER_HOST" "crontab ~/temp-cron.txt && rm ~/temp-cron.txt" 2>/dev/null; then
            success "Cron jobs restored successfully"
            log "Previous cron jobs backed up to ~/$current_backup"
            return 0
        else
            error "Failed to install cron jobs"
            return 1
        fi
    else
        error "Failed to copy cron jobs file to server"
        return 1
    fi
}

# Function to restore server scripts
restore_server_scripts() {
    log "Restoring server scripts..."
    
    local scripts_restored=0
    
    # Script paths and names
    declare -A scripts=(
        ["~/duckdns/duck.sh"]="duck.sh"
        ["/home/sudhan0312/.acme.sh/acme.sh"]="acme.sh"
        ["~/server_backup.sh"]="server_backup.sh"
    )
    
    for script_path in "${!scripts[@]}"; do
        local script_name="${scripts[$script_path]}"
        local backup_file="${script_name}-${TIMESTAMP}.sh"
        
        if [ -f "$backup_file" ]; then
            log "Restoring $script_name to $script_path..."
            
            # Create backup of existing script
            local backup_name="restore-backup-${script_name}-$(date +%Y%m%d-%H%M%S).sh"
            ssh "$SERVER_USER@$SERVER_HOST" "cp $script_path ~/$backup_name" 2>/dev/null || true
            
            # Restore the script
            if scp "$backup_file" "$SERVER_USER@$SERVER_HOST:$script_path" 2>/dev/null; then
                ssh "$SERVER_USER@$SERVER_HOST" "chmod +x $script_path" 2>/dev/null
                success "Restored $script_name"
                scripts_restored=$((scripts_restored + 1))
            else
                warning "Failed to restore $script_name"
            fi
        else
            warning "Backup file not found: $backup_file"
        fi
    done
    
    success "Restored $scripts_restored server scripts"
}

# Main restore process
main() {
    log "Starting server restore process..."
    
    if ! test_ssh_connection; then
        exit 1
    fi
    
    # Restore cron jobs
    restore_cron_jobs
    
    # Restore server scripts
    restore_server_scripts
    
    success "Server restore completed!"
    log "Please verify that all services are working correctly"
}

# Run main function
main "$@"
EOF

    chmod +x "$restore_script"
    success "Restore script created: $restore_script"
}

# Function to create backup manifest
create_backup_manifest() {
    log "Creating backup manifest..."
    
    local manifest_file="$BACKUP_DIR/backup-manifest.txt"
    
    cat > "$manifest_file" << EOF
# Complete Server Backup Manifest
# Created: $(date)
# Server: $SERVER_USER@$SERVER_HOST
# Backup Directory: $BACKUP_DIR
# Timestamp: $TIMESTAMP

## Backup Contents:

### Cron Jobs:
- server-cron-jobs-${TIMESTAMP}.txt

### Server Scripts:
EOF
    
    # List script files
    for script_file in "$BACKUP_DIR"/*.sh; do
        if [ -f "$script_file" ] && [[ "$script_file" != *"restore-server.sh" ]]; then
            local filename=$(basename "$script_file")
            echo "- $filename" >> "$manifest_file"
        fi
    done
    
    echo "" >> "$manifest_file"
    echo "### System Information:" >> "$manifest_file"
    echo "- system-info-${TIMESTAMP}.txt" >> "$manifest_file"
    
    echo "" >> "$manifest_file"
    echo "### Restore Script:" >> "$manifest_file"
    echo "- restore-server.sh" >> "$manifest_file"
    
    echo "" >> "$manifest_file"
    echo "## File Sizes:" >> "$manifest_file"
    ls -lh "$BACKUP_DIR"/* >> "$manifest_file" 2>/dev/null || true
    
    success "Backup manifest created: $manifest_file"
}

# Function to show backup summary
show_backup_summary() {
    echo ""
    info "Backup Summary:"
    echo "=================="
    echo "Backup Directory: $BACKUP_DIR"
    echo "Timestamp: $TIMESTAMP"
    echo "Server: $SERVER_USER@$SERVER_HOST"
    echo ""
    
    echo "Files created:"
    ls -la "$BACKUP_DIR"/
    echo ""
    
    echo "Total backup size:"
    du -sh "$BACKUP_DIR"
    echo ""
    
    echo "To restore this backup:"
    echo "1. Copy the backup directory to your local machine"
    echo "2. cd into the backup directory"
    echo "3. Run: ./restore-server.sh"
    echo ""
    
    echo "Backup manifest:"
    cat "$BACKUP_DIR/backup-manifest.txt"
}

# Main backup function
main() {
    log "Starting complete server backup..."
    
    create_backup_dir
    
    if ! test_ssh_connection; then
        exit 1
    fi
    
    # Backup cron jobs
    backup_cron_jobs
    
    # Backup server scripts
    backup_server_scripts
    
    # Backup system information
    backup_system_info
    
    # Create restore script
    create_restore_script
    
    # Create backup manifest
    create_backup_manifest
    
    success "Complete server backup finished!"
    
    # Show summary
    show_backup_summary
}

# Main script logic
case "${1:-}" in
    "backup")
        main
        ;;
    "help"|"-h"|"--help")
        echo "Complete Server Backup Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  backup     - Create complete server backup"
        echo "  help       - Show this help message"
        echo ""
        echo "This script backs up:"
        echo "  - All cron jobs"
        echo "  - Server scripts (duck.sh, acme.sh, server_backup.sh)"
        echo "  - System information"
        echo "  - Creates a restore script"
        echo ""
        echo "Prerequisites:"
        echo "  - SSH access to server (passwordless recommended)"
        echo "  - Proper permissions on server"
        echo ""
        echo "Example:"
        echo "  $0 backup    # Create complete server backup"
        ;;
    *)
        echo "Complete Server Backup Script"
        echo ""
        echo "Usage: $0 <command>"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick command:"
        echo "  $0 backup    - Create complete server backup"
        ;;
esac
