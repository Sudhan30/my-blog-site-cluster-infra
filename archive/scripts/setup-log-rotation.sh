#!/bin/bash

# Log Rotation and Cleanup Setup Script
# This script sets up automatic log rotation and cleanup for deployment monitoring

set -e

echo "🗂️  Setting up log rotation and cleanup..."
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

# Step 1: Create logrotate configuration
print_status "Step 1: Creating logrotate configuration..."

sudo tee /etc/logrotate.d/deployment-monitor > /dev/null << 'EOF'
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
EOF

print_success "Logrotate configuration created"
echo ""

# Step 2: Create log cleanup script
print_status "Step 2: Creating log cleanup script..."

cat > /tmp/cleanup-logs.sh << 'EOF'
#!/bin/bash
# Log cleanup script - removes logs older than 1 week

LOG_DIRS=("/tmp" "/var/log")
RETENTION_DAYS=7

echo "$(date): Starting log cleanup..."

for dir in "${LOG_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "Cleaning logs in $dir older than $RETENTION_DAYS days..."
        
        # Find and remove log files older than retention period
        find "$dir" -name "*.log" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find "$dir" -name "*.log.*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        # Clean up empty log files
        find "$dir" -name "*.log" -type f -size 0 -delete 2>/dev/null || true
    fi
done

# Clean up specific monitoring logs
if [ -f "/tmp/deployment-monitor.log" ]; then
    # Keep only last 1000 lines if file is too large (>10MB)
    if [ $(stat -f%z "/tmp/deployment-monitor.log" 2>/dev/null || stat -c%s "/tmp/deployment-monitor.log" 2>/dev/null) -gt 10485760 ]; then
        tail -n 1000 "/tmp/deployment-monitor.log" > "/tmp/deployment-monitor.log.tmp"
        mv "/tmp/deployment-monitor.log.tmp" "/tmp/deployment-monitor.log"
        echo "$(date): Trimmed deployment-monitor.log to last 1000 lines"
    fi
fi

echo "$(date): Log cleanup completed"
EOF

chmod +x /tmp/cleanup-logs.sh
print_success "Log cleanup script created"
echo ""

# Step 3: Create cron job for automatic cleanup
print_status "Step 3: Setting up automatic cleanup cron job..."

# Add cron job to run cleanup daily at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /tmp/cleanup-logs.sh >> /tmp/cleanup-logs.log 2>&1") | crontab -

print_success "Cron job configured for daily cleanup at 2 AM"
echo ""

# Step 4: Update monitoring script to include log rotation
print_status "Step 4: Updating monitoring script with log rotation..."

cat > /tmp/monitor-deployments-rotated.sh << 'EOF'
#!/bin/bash
# Enhanced deployment monitoring script with log rotation

NAMESPACE="web"
APP_LABEL="app=blog"
LOG_FILE="/tmp/deployment-monitor.log"
MAX_LOG_SIZE=10485760  # 10MB

# Function to rotate log if it gets too large
rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        local file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
        if [ "$file_size" -gt "$MAX_LOG_SIZE" ]; then
            # Keep last 1000 lines and compress the rest
            tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp"
            mv "${LOG_FILE}.tmp" "$LOG_FILE"
            echo "$(date): Log rotated - kept last 1000 lines" >> "$LOG_FILE"
        fi
    fi
}

while true; do
    TIMESTAMP=$(date)
    
    # Rotate log if needed
    rotate_log
    
    # Check pod status
    POD_STATUS=$(kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers 2>/dev/null | awk '{print $3}' | sort | uniq -c)
    
    # Check deployment status
    DEPLOY_STATUS=$(kubectl -n $NAMESPACE get deploy blog --no-headers 2>/dev/null | awk '{print $2}')
    
    # Check if any pods are in error state
    ERROR_PODS=$(kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers 2>/dev/null | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l)
    
    # Log status
    echo "$TIMESTAMP - Pods: $POD_STATUS, Deployment: $DEPLOY_STATUS, Errors: $ERROR_PODS" >> $LOG_FILE
    
    # Alert if there are errors
    if [ "$ERROR_PODS" -gt 0 ]; then
        echo "🚨 ALERT: $ERROR_PODS pods in error state at $TIMESTAMP" >> $LOG_FILE
        echo "🚨 ALERT: $ERROR_PODS pods in error state at $TIMESTAMP"
        
        # Get error details
        kubectl -n $NAMESPACE get pods -l $APP_LABEL | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" >> $LOG_FILE
    fi
    
    sleep 60
done
EOF

chmod +x /tmp/monitor-deployments-rotated.sh
print_success "Enhanced monitoring script with log rotation created"
echo ""

# Step 5: Update systemd service to use new monitoring script
print_status "Step 5: Updating systemd service..."

sudo tee /etc/systemd/system/deployment-monitor.service > /dev/null << EOF
[Unit]
Description=Deployment Monitoring with Log Rotation
After=network.target

[Service]
Type=simple
User=sudhan0312
ExecStart=/tmp/monitor-deployments-rotated.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and restart service
sudo systemctl daemon-reload
sudo systemctl restart deployment-monitor.service

print_success "Systemd service updated with log rotation"
echo ""

# Step 6: Create log viewing utilities
print_status "Step 6: Creating log viewing utilities..."

cat > /tmp/view-logs.sh << 'EOF'
#!/bin/bash
# Log viewing utility script

LOG_FILE="/tmp/deployment-monitor.log"
LINES=${1:-50}  # Default to last 50 lines

echo "📋 Showing last $LINES lines of deployment monitor log:"
echo "=================================================="

if [ -f "$LOG_FILE" ]; then
    tail -n $LINES "$LOG_FILE"
else
    echo "Log file not found: $LOG_FILE"
fi

echo ""
echo "📊 Log file info:"
if [ -f "$LOG_FILE" ]; then
    echo "Size: $(du -h "$LOG_FILE" | cut -f1)"
    echo "Lines: $(wc -l < "$LOG_FILE")"
    echo "Last modified: $(stat -f%Sm "$LOG_FILE" 2>/dev/null || stat -c%y "$LOG_FILE" 2>/dev/null)"
else
    echo "File does not exist"
fi
EOF

chmod +x /tmp/view-logs.sh
print_success "Log viewing utility created"
echo ""

# Step 7: Test the setup
print_status "Step 7: Testing log rotation setup..."

# Test logrotate configuration
sudo logrotate -d /etc/logrotate.d/deployment-monitor

# Run cleanup script once
/tmp/cleanup-logs.sh

print_success "Log rotation setup completed and tested"
echo ""

# Summary
echo "📋 LOG ROTATION SETUP SUMMARY:"
echo "  ✅ Logrotate configuration created"
echo "  ✅ Automatic cleanup script created"
echo "  ✅ Cron job scheduled (daily at 2 AM)"
echo "  ✅ Enhanced monitoring with log rotation"
echo "  ✅ Systemd service updated"
echo "  ✅ Log viewing utility created"
echo ""
echo "📝 USEFUL COMMANDS:"
echo "  • View recent logs: /tmp/view-logs.sh [lines]"
echo "  • Manual cleanup: /tmp/cleanup-logs.sh"
echo "  • Check cron jobs: crontab -l"
echo "  • Test logrotate: sudo logrotate -d /etc/logrotate.d/deployment-monitor"
echo "  • Monitor logs: tail -f /tmp/deployment-monitor.log"
echo ""
echo "🎉 Log rotation and cleanup setup completed!"
