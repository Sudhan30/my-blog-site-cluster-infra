#!/bin/bash

# Server Scripts Backup and Restore Script
# This script backs up and restores server scripts referenced in cron jobs

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

# Server connection details
SERVER_USER="sudhan0312"
SERVER_HOST="suddu-um790-server"
SERVER_SSH_KEY=""  # Add your SSH key path if needed

# Script paths on server
DUCK_SCRIPT="~/duckdns/duck.sh"
ACME_SCRIPT="/home/sudhan0312/.acme.sh/acme.sh"
BACKUP_SCRIPT="~/server_backup.sh"

# Local backup directory
BACKUP_DIR="server-scripts-backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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

# Function to backup a single script
backup_script() {
    local script_path="$1"
    local script_name="$2"
    local local_path="$3"
    
    log "Backing up $script_name from $script_path..."
    
    # Create timestamped backup
    local backup_file="$BACKUP_DIR/${script_name}-${TIMESTAMP}.sh"
    
    if ssh "$SERVER_USER@$SERVER_HOST" "test -f $script_path" 2>/dev/null; then
        if ssh "$SERVER_USER@$SERVER_HOST" "cat $script_path" > "$backup_file" 2>/dev/null; then
            success "Backed up $script_name to $backup_file"
            
            # Also create a current version (without timestamp)
            cp "$backup_file" "$local_path"
            success "Created current version: $local_path"
            
            # Show file info
            local file_size=$(wc -c < "$backup_file")
            local line_count=$(wc -l < "$backup_file")
            echo "  File size: $file_size bytes"
            echo "  Lines: $line_count"
            
            return 0
        else
            error "Failed to read $script_name from server"
            return 1
        fi
    else
        warning "Script $script_name not found at $script_path on server"
        return 1
    fi
}

# Function to backup all scripts
backup_all_scripts() {
    log "Starting backup of all server scripts..."
    
    create_backup_dir
    
    if ! test_ssh_connection; then
        return 1
    fi
    
    local backup_success=true
    
    # Backup DuckDNS script
    if ! backup_script "$DUCK_SCRIPT" "duck" "duck.sh"; then
        backup_success=false
    fi
    
    # Backup ACME script
    if ! backup_script "$ACME_SCRIPT" "acme" "acme.sh"; then
        backup_success=false
    fi
    
    # Backup server backup script
    if ! backup_script "$BACKUP_SCRIPT" "server_backup" "server_backup.sh"; then
        backup_success=false
    fi
    
    # Create backup manifest
    local manifest_file="$BACKUP_DIR/backup-manifest-${TIMESTAMP}.txt"
    cat > "$manifest_file" << EOF
# Server Scripts Backup Manifest
# Created: $(date)
# Server: $SERVER_USER@$SERVER_HOST

## Scripts Backed Up:
EOF
    
    if [ -f "duck.sh" ]; then
        echo "- duck.sh (DuckDNS update script)" >> "$manifest_file"
    fi
    
    if [ -f "acme.sh" ]; then
        echo "- acme.sh (SSL certificate management script)" >> "$manifest_file"
    fi
    
    if [ -f "server_backup.sh" ]; then
        echo "- server_backup.sh (Server backup script)" >> "$manifest_file"
    fi
    
    echo "" >> "$manifest_file"
    echo "## Backup Files:" >> "$manifest_file"
    ls -la "$BACKUP_DIR"/*.sh >> "$manifest_file" 2>/dev/null || true
    
    success "Backup manifest created: $manifest_file"
    
    if [ "$backup_success" = true ]; then
        success "All scripts backed up successfully"
    else
        warning "Some scripts could not be backed up"
    fi
    
    # Show backup summary
    echo ""
    log "Backup Summary:"
    echo "Backup directory: $BACKUP_DIR"
    echo "Timestamp: $TIMESTAMP"
    echo ""
    echo "Files created:"
    ls -la "$BACKUP_DIR"/*.sh 2>/dev/null || echo "No backup files found"
    echo ""
    echo "Current versions:"
    ls -la *.sh 2>/dev/null || echo "No current script files found"
}

# Function to restore a script to server
restore_script() {
    local script_name="$1"
    local script_path="$2"
    
    if [ -z "$script_name" ] || [ -z "$script_path" ]; then
        error "Usage: restore_script <script_name> <server_path>"
        return 1
    fi
    
    local local_file="${script_name}.sh"
    
    if [ ! -f "$local_file" ]; then
        error "Local script file $local_file not found"
        return 1
    fi
    
    log "Restoring $script_name to $script_path on server..."
    
    # Create backup before restoring
    local backup_name="restore-backup-${script_name}-$(date +%Y%m%d-%H%M%S).sh"
    
    if ssh "$SERVER_USER@$SERVER_HOST" "test -f $script_path" 2>/dev/null; then
        ssh "$SERVER_USER@$SERVER_HOST" "cp $script_path ~/$backup_name" 2>/dev/null || true
        log "Created backup of existing script: ~/$backup_name"
    fi
    
    # Restore the script
    if scp "$local_file" "$SERVER_USER@$SERVER_HOST:$script_path" 2>/dev/null; then
        # Set executable permissions
        ssh "$SERVER_USER@$SERVER_HOST" "chmod +x $script_path" 2>/dev/null
        success "Restored $script_name to server"
        return 0
    else
        error "Failed to restore $script_name to server"
        return 1
    fi
}

# Function to restore all scripts
restore_all_scripts() {
    log "Starting restore of all server scripts..."
    
    if ! test_ssh_connection; then
        return 1
    fi
    
    local restore_success=true
    
    # Restore DuckDNS script
    if [ -f "duck.sh" ]; then
        if ! restore_script "duck" "$DUCK_SCRIPT"; then
            restore_success=false
        fi
    else
        warning "duck.sh not found locally, skipping"
    fi
    
    # Restore ACME script
    if [ -f "acme.sh" ]; then
        if ! restore_script "acme" "$ACME_SCRIPT"; then
            restore_success=false
        fi
    else
        warning "acme.sh not found locally, skipping"
    fi
    
    # Restore server backup script
    if [ -f "server_backup.sh" ]; then
        if ! restore_script "server_backup" "$BACKUP_SCRIPT"; then
            restore_success=false
        fi
    else
        warning "server_backup.sh not found locally, skipping"
    fi
    
    if [ "$restore_success" = true ]; then
        success "All scripts restored successfully"
    else
        warning "Some scripts could not be restored"
    fi
}

# Function to show script information
show_script_info() {
    log "Server Script Information:"
    echo ""
    
    if ! test_ssh_connection; then
        return 1
    fi
    
    # Check DuckDNS script
    echo "🔍 DuckDNS Script ($DUCK_SCRIPT):"
    if ssh "$SERVER_USER@$SERVER_HOST" "test -f $DUCK_SCRIPT" 2>/dev/null; then
        local duck_size=$(ssh "$SERVER_USER@$SERVER_HOST" "wc -c < $DUCK_SCRIPT" 2>/dev/null)
        local duck_lines=$(ssh "$SERVER_USER@$SERVER_HOST" "wc -l < $DUCK_SCRIPT" 2>/dev/null)
        echo "  ✅ Exists - Size: $duck_size bytes, Lines: $duck_lines"
    else
        echo "  ❌ Not found"
    fi
    
    # Check ACME script
    echo "🔍 ACME Script ($ACME_SCRIPT):"
    if ssh "$SERVER_USER@$SERVER_HOST" "test -f $ACME_SCRIPT" 2>/dev/null; then
        local acme_size=$(ssh "$SERVER_USER@$SERVER_HOST" "wc -c < $ACME_SCRIPT" 2>/dev/null)
        local acme_lines=$(ssh "$SERVER_USER@$SERVER_HOST" "wc -l < $ACME_SCRIPT" 2>/dev/null)
        echo "  ✅ Exists - Size: $acme_size bytes, Lines: $acme_lines"
    else
        echo "  ❌ Not found"
    fi
    
    # Check server backup script
    echo "🔍 Server Backup Script ($BACKUP_SCRIPT):"
    if ssh "$SERVER_USER@$SERVER_HOST" "test -f $BACKUP_SCRIPT" 2>/dev/null; then
        local backup_size=$(ssh "$SERVER_USER@$SERVER_HOST" "wc -c < $BACKUP_SCRIPT" 2>/dev/null)
        local backup_lines=$(ssh "$SERVER_USER@$SERVER_HOST" "wc -l < $BACKUP_SCRIPT" 2>/dev/null)
        echo "  ✅ Exists - Size: $backup_size bytes, Lines: $backup_lines"
    else
        echo "  ❌ Not found"
    fi
    
    echo ""
    echo "📁 Local Backup Files:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -la "$BACKUP_DIR"/*.sh 2>/dev/null || echo "  No backup files found"
    else
        echo "  No backup directory found"
    fi
    
    echo ""
    echo "📄 Current Local Files:"
    ls -la *.sh 2>/dev/null || echo "  No current script files found"
}

# Function to create script templates
create_templates() {
    log "Creating script templates..."
    
    # DuckDNS template
    cat > "duck.sh.template" << 'EOF'
#!/bin/bash

# DuckDNS Update Script Template
# Update this with your actual DuckDNS token and domain

DOMAIN="your-domain.duckdns.org"
TOKEN="your-duckdns-token"

# Get current public IP
CURRENT_IP=$(curl -s https://api.ipify.org)

# Update DuckDNS
curl -s "https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=$CURRENT_IP"

echo "$(date): Updated DuckDNS for $DOMAIN to $CURRENT_IP" >> ~/duckdns.log
EOF

    # ACME template
    cat > "acme.sh.template" << 'EOF'
#!/bin/bash

# ACME.sh SSL Certificate Management Template
# This is a template - the actual acme.sh script is more complex

# Set ACME.sh directory
ACME_DIR="/home/sudhan0312/.acme.sh"

# Run ACME.sh with cron flag
"$ACME_DIR/acme.sh" --cron --home "$ACME_DIR"

echo "$(date): ACME.sh certificate check completed" >> ~/acme.log
EOF

    # Server backup template
    cat > "server_backup.sh.template" << 'EOF'
#!/bin/bash

# Server Backup Script Template
# Customize this for your backup needs

BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d-%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Example backup commands (customize as needed)
# tar -czf "$BACKUP_DIR/config-backup-$DATE.tar.gz" /etc
# tar -czf "$BACKUP_DIR/home-backup-$DATE.tar.gz" /home
# tar -czf "$BACKUP_DIR/var-backup-$DATE.tar.gz" /var

echo "$(date): Server backup completed" >> ~/backup.log

# Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
EOF

    success "Script templates created:"
    echo "  - duck.sh.template"
    echo "  - acme.sh.template"
    echo "  - server_backup.sh.template"
    echo ""
    echo "Customize these templates and rename them to .sh files"
}

# Main script logic
case "${1:-}" in
    "backup")
        backup_all_scripts
        ;;
    "restore")
        restore_all_scripts
        ;;
    "info")
        show_script_info
        ;;
    "templates")
        create_templates
        ;;
    "help"|"-h"|"--help")
        echo "Server Scripts Backup and Restore Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  backup     - Backup all server scripts to local directory"
        echo "  restore    - Restore all local scripts to server"
        echo "  info       - Show information about server scripts"
        echo "  templates  - Create script templates"
        echo "  help       - Show this help message"
        echo ""
        echo "Scripts backed up:"
        echo "  - DuckDNS update script (~/duckdns/duck.sh)"
        echo "  - ACME.sh SSL certificate script (/home/sudhan0312/.acme.sh/acme.sh)"
        echo "  - Server backup script (~/server_backup.sh)"
        echo ""
        echo "Prerequisites:"
        echo "  - SSH access to server (passwordless recommended)"
        echo "  - Proper permissions on server"
        echo ""
        echo "Examples:"
        echo "  $0 backup     # Backup all scripts from server"
        echo "  $0 restore    # Restore all scripts to server"
        echo "  $0 info       # Show script information"
        ;;
    *)
        echo "Server Scripts Backup and Restore Script"
        echo ""
        echo "Usage: $0 <command>"
        echo "Run '$0 help' for detailed usage information"
        echo ""
        echo "Quick commands:"
        echo "  $0 backup    - Backup all server scripts"
        echo "  $0 restore   - Restore all scripts to server"
        echo "  $0 info      - Show script information"
        ;;
esac
