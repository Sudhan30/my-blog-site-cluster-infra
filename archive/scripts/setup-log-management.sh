#!/bin/bash

# Dedicated Log Management Setup
# This sets up log management that runs independently of deployments

set -e

echo "🗂️  Setting up Dedicated Log Management..."
echo "📅 $(date)"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Step 1: Create dedicated log cleanup script
print_status "Step 1: Creating dedicated log cleanup script..."

cat > /tmp/log-cleanup.sh << 'EOF'
#!/bin/bash

# Dedicated log cleanup script
# Runs every 2 hours to manage logs independently

LOG_DIRS=("/tmp" "/var/log")
RETENTION_DAYS=7
MAX_LOG_SIZE=10485760  # 10MB
LOG_CLEANUP_LOG="/tmp/log-cleanup.log"

# Function to log with timestamp
log_cleanup() {
    echo "$(date): $1" | tee -a "$LOG_CLEANUP_LOG"
}

log_cleanup "Starting log cleanup process..."

# Clean up old log files
for dir in "${LOG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log_cleanup "Cleaning logs in $dir older than $RETENTION_DAYS days..."
        
        # Find and remove log files older than retention period
        OLD_LOGS=$(find "$dir" -name "*.log" -type f -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
        find "$dir" -name "*.log" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find "$dir" -name "*.log.*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        log_cleanup "Removed $OLD_LOGS old log files from $dir"
    fi
done

# Clean up empty log files
EMPTY_LOGS=$(find /tmp -name "*.log" -type f -size 0 2>/dev/null | wc -l)
find /tmp -name "*.log" -type f -size 0 -delete 2>/dev/null || true
log_cleanup "Removed $EMPTY_LOGS empty log files"

# Manage specific monitoring logs
MONITORING_LOGS=(
    "/tmp/deployment-monitor.log"
    "/tmp/test-results.log"
    "/tmp/flux-reconcile.log"
    "/tmp/server-automation.log"
    "/tmp/cron-automation.log"
    "/tmp/webhook-automation.log"
    "/tmp/log-cleanup.log"
)

for log_file in "${MONITORING_LOGS[@]}"; do
    if [ -f "$log_file" ]; then
        # Check file size
        FILE_SIZE=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
        
        if [ "$FILE_SIZE" -gt "$MAX_LOG_SIZE" ]; then
            # Keep last 1000 lines if file is too large
            log_cleanup "Trimming large log file: $(basename "$log_file") ($(du -h "$log_file" | cut -f1))"
            tail -n 1000 "$log_file" > "${log_file}.tmp"
            mv "${log_file}.tmp" "$log_file"
            log_cleanup "Trimmed $(basename "$log_file") to last 1000 lines"
        else
            log_cleanup "Log file $(basename "$log_file") size OK ($(du -h "$log_file" | cut -f1))"
        fi
    fi
done

# Clean up old compressed logs
COMPRESSED_LOGS=$(find /tmp -name "*.log.*" -type f -mtime +3 2>/dev/null | wc -l)
find /tmp -name "*.log.*" -type f -mtime +3 -delete 2>/dev/null || true
log_cleanup "Removed $COMPRESSED_LOGS old compressed log files"

# Clean up temporary files
TEMP_FILES=$(find /tmp -name "tmp.*" -type f -mtime +1 2>/dev/null | wc -l)
find /tmp -name "tmp.*" -type f -mtime +1 -delete 2>/dev/null || true
log_cleanup "Removed $TEMP_FILES temporary files"

# Report disk usage
DISK_USAGE=$(df -h /tmp | tail -1 | awk '{print $5}')
log_cleanup "Current /tmp disk usage: $DISK_USAGE"

log_cleanup "Log cleanup process completed successfully"
EOF

chmod +x /tmp/log-cleanup.sh
print_success "Dedicated log cleanup script created"
echo ""

# Step 2: Create logrotate configuration
print_status "Step 2: Creating logrotate configuration..."

sudo tee /etc/logrotate.d/monitoring-logs > /dev/null << 'EOF'
# Monitoring logs rotation
/tmp/deployment-monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 sudhan0312 sudhan0312
    postrotate
        # Restart monitoring service if it's running
        systemctl reload deployment-monitor.service 2>/dev/null || true
    endscript
}

/tmp/test-results.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 sudhan0312 sudhan0312
}

/tmp/flux-reconcile.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 sudhan0312 sudhan0312
}

/tmp/server-automation.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 sudhan0312 sudhan0312
}

/tmp/cron-automation.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 sudhan0312 sudhan0312
}

/tmp/webhook-automation.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 sudhan0312 sudhan0312
}

/tmp/log-cleanup.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 sudhan0312 sudhan0312
}
EOF

print_success "Logrotate configuration created"
echo ""

# Step 3: Set up cron jobs for log management
print_status "Step 3: Setting up cron jobs for log management..."

# Remove any existing log cleanup cron jobs
crontab -l 2>/dev/null | grep -v "log-cleanup.sh" | crontab - 2>/dev/null || true

# Add new cron jobs
(crontab -l 2>/dev/null; cat << 'EOF'
# Log management - runs every 2 hours
0 */2 * * * /tmp/log-cleanup.sh >> /tmp/log-cleanup.log 2>&1

# Logrotate - runs daily at 3 AM
0 3 * * * /usr/sbin/logrotate /etc/logrotate.d/monitoring-logs >> /tmp/log-cleanup.log 2>&1

# Weekly deep cleanup - runs every Sunday at 4 AM
0 4 * * 0 /tmp/log-cleanup.sh --deep >> /tmp/log-cleanup.log 2>&1
EOF
) | crontab -

print_success "Cron jobs configured for log management"
echo ""

# Step 4: Create log monitoring script
print_status "Step 4: Creating log monitoring script..."

cat > /tmp/log-monitor.sh << 'EOF'
#!/bin/bash

# Log monitoring script
# Monitors log file sizes and disk usage

LOG_MONITOR_LOG="/tmp/log-monitor.log"
ALERT_THRESHOLD=80  # Alert if disk usage > 80%

# Function to log with timestamp
log_monitor() {
    echo "$(date): $1" | tee -a "$LOG_MONITOR_LOG"
}

log_monitor "Starting log monitoring..."

# Check disk usage
DISK_USAGE=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt "$ALERT_THRESHOLD" ]; then
    log_monitor "⚠️  ALERT: Disk usage is ${DISK_USAGE}% (threshold: ${ALERT_THRESHOLD}%)"
    
    # Force immediate cleanup
    /tmp/log-cleanup.sh
    log_monitor "Emergency cleanup triggered"
else
    log_monitor "✅ Disk usage OK: ${DISK_USAGE}%"
fi

# Check individual log file sizes
MONITORING_LOGS=(
    "/tmp/deployment-monitor.log"
    "/tmp/test-results.log"
    "/tmp/flux-reconcile.log"
    "/tmp/server-automation.log"
    "/tmp/cron-automation.log"
    "/tmp/webhook-automation.log"
    "/tmp/log-cleanup.log"
)

log_monitor "Checking individual log file sizes:"
for log_file in "${MONITORING_LOGS[@]}"; do
    if [ -f "$log_file" ]; then
        SIZE=$(du -h "$log_file" | cut -f1)
        LINES=$(wc -l < "$log_file" 2>/dev/null || echo "0")
        log_monitor "  $(basename "$log_file"): $SIZE ($LINES lines)"
    else
        log_monitor "  $(basename "$log_file"): Not found"
    fi
done

log_monitor "Log monitoring completed"
EOF

chmod +x /tmp/log-monitor.sh
print_success "Log monitoring script created"
echo ""

# Step 5: Add log monitoring to cron
print_status "Step 5: Adding log monitoring to cron..."

# Add log monitoring cron job (runs every hour)
(crontab -l 2>/dev/null; echo "0 * * * * /tmp/log-monitor.sh >> /tmp/log-monitor.log 2>&1") | crontab -

print_success "Log monitoring cron job added"
echo ""

# Step 6: Create log management utilities
print_status "Step 6: Creating log management utilities..."

cat > /tmp/log-utils.sh << 'EOF'
#!/bin/bash

# Log management utilities
# Quick commands for log management

case "$1" in
    "status")
        echo "📊 Log Management Status:"
        echo "========================="
        echo "Disk usage: $(df -h /tmp | tail -1 | awk '{print $5}')"
        echo "Log cleanup cron: $(crontab -l 2>/dev/null | grep log-cleanup.sh | wc -l) jobs"
        echo "Logrotate config: $([ -f /etc/logrotate.d/monitoring-logs ] && echo "✅ Configured" || echo "❌ Missing")"
        echo ""
        echo "Recent log cleanup activity:"
        tail -5 /tmp/log-cleanup.log 2>/dev/null || echo "No cleanup log found"
        ;;
    
    "clean")
        echo "🧹 Running immediate log cleanup..."
        /tmp/log-cleanup.sh
        ;;
    
    "monitor")
        echo "👀 Running log monitoring..."
        /tmp/log-monitor.sh
        ;;
    
    "sizes")
        echo "📏 Log file sizes:"
        echo "=================="
        find /tmp -name "*.log" -type f -exec du -h {} \; | sort -hr
        ;;
    
    "view")
        LOG_FILE=${2:-"/tmp/log-cleanup.log"}
        LINES=${3:-50}
        echo "📋 Showing last $LINES lines of $(basename "$LOG_FILE"):"
        echo "=================================================="
        if [ -f "$LOG_FILE" ]; then
            tail -n $LINES "$LOG_FILE"
        else
            echo "Log file not found: $LOG_FILE"
        fi
        ;;
    
    "test")
        echo "🧪 Testing log management..."
        echo "Running log cleanup test..."
        /tmp/log-cleanup.sh
        echo "Running log monitoring test..."
        /tmp/log-monitor.sh
        echo "✅ Log management test completed"
        ;;
    
    *)
        echo "📋 Log Management Utilities:"
        echo "============================"
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  status           - Show log management status"
        echo "  clean            - Run immediate log cleanup"
        echo "  monitor          - Run log monitoring"
        echo "  sizes            - Show log file sizes"
        echo "  view [file] [lines] - View log file (default: log-cleanup.log, 50 lines)"
        echo "  test             - Test log management"
        echo ""
        echo "Examples:"
        echo "  $0 status        - Check log management status"
        echo "  $0 clean         - Clean logs immediately"
        echo "  $0 view deployment-monitor.log 100 - View last 100 lines"
        echo "  $0 sizes         - Show all log file sizes"
        ;;
esac
EOF

chmod +x /tmp/log-utils.sh
print_success "Log management utilities created"
echo ""

# Step 7: Test the setup
print_status "Step 7: Testing log management setup..."

# Test logrotate configuration
sudo logrotate -d /etc/logrotate.d/monitoring-logs > /dev/null 2>&1 && print_success "Logrotate configuration valid" || print_warning "Logrotate configuration issue"

# Run initial cleanup
/tmp/log-cleanup.sh

# Run initial monitoring
/tmp/log-monitor.sh

print_success "Log management setup tested"
echo ""

# Step 8: Create systemd service for log management
print_status "Step 8: Creating systemd service for log management..."

sudo tee /etc/systemd/system/log-management.service > /dev/null << 'EOF'
[Unit]
Description=Log Management Service
After=network.target

[Service]
Type=oneshot
User=sudhan0312
ExecStart=/tmp/log-cleanup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create timer for the service
sudo tee /etc/systemd/system/log-management.timer > /dev/null << 'EOF'
[Unit]
Description=Run log management every 2 hours
Requires=log-management.service

[Timer]
OnCalendar=*:0/2:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable log-management.timer
sudo systemctl start log-management.timer

print_success "Systemd timer service created and started"
echo ""

# Summary
echo "🗂️  LOG MANAGEMENT SETUP COMPLETED!"
echo "===================================="
echo ""
echo "📋 What's Been Set Up:"
echo "  ✅ Dedicated log cleanup script (runs every 2 hours)"
echo "  ✅ Logrotate configuration (daily rotation)"
echo "  ✅ Log monitoring script (runs every hour)"
echo "  ✅ Cron jobs for automated management"
echo "  ✅ Systemd timer service (backup scheduling)"
echo "  ✅ Log management utilities"
echo ""
echo "⏰ Schedule:"
echo "  • Log cleanup: Every 2 hours"
echo "  • Log monitoring: Every hour"
echo "  • Log rotation: Daily at 3 AM"
echo "  • Deep cleanup: Weekly on Sunday at 4 AM"
echo ""
echo "📝 Useful Commands:"
echo "  • Check status: /tmp/log-utils.sh status"
echo "  • Clean now: /tmp/log-utils.sh clean"
echo "  • View logs: /tmp/log-utils.sh view [file] [lines]"
echo "  • Check sizes: /tmp/log-utils.sh sizes"
echo "  • Test system: /tmp/log-utils.sh test"
echo ""
echo "🎉 Log management is now completely automated!"
echo "   Logs will be cleaned every 2 hours regardless of deployments!"
