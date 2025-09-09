#!/bin/bash

# Simple Log Management Script
# Quick commands for managing deployment monitoring logs

LOG_FILE="/tmp/deployment-monitor.log"
RETENTION_DAYS=7

case "$1" in
    "view")
        LINES=${2:-50}
        echo "📋 Showing last $LINES lines of deployment monitor log:"
        echo "=================================================="
        if [ -f "$LOG_FILE" ]; then
            tail -n $LINES "$LOG_FILE"
        else
            echo "Log file not found: $LOG_FILE"
        fi
        ;;
    
    "clean")
        echo "🧹 Cleaning logs older than $RETENTION_DAYS days..."
        
        # Clean up old log files
        find /tmp -name "*.log" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find /tmp -name "*.log.*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        # Trim current log if too large (>10MB)
        if [ -f "$LOG_FILE" ]; then
            FILE_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
            if [ "$FILE_SIZE" -gt 10485760 ]; then
                echo "📏 Log file is large ($(du -h "$LOG_FILE" | cut -f1)), trimming to last 1000 lines..."
                tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp"
                mv "${LOG_FILE}.tmp" "$LOG_FILE"
                echo "✅ Log trimmed successfully"
            else
                echo "✅ Log file size is acceptable ($(du -h "$LOG_FILE" | cut -f1))"
            fi
        fi
        
        echo "✅ Log cleanup completed"
        ;;
    
    "info")
        echo "📊 Log file information:"
        echo "========================"
        if [ -f "$LOG_FILE" ]; then
            echo "File: $LOG_FILE"
            echo "Size: $(du -h "$LOG_FILE" | cut -f1)"
            echo "Lines: $(wc -l < "$LOG_FILE")"
            echo "Last modified: $(stat -f%Sm "$LOG_FILE" 2>/dev/null || stat -c%y "$LOG_FILE" 2>/dev/null)"
            echo "Age: $(find "$LOG_FILE" -printf '%TY-%Tm-%Td %TH:%TM' 2>/dev/null || stat -c%y "$LOG_FILE" 2>/dev/null | cut -d' ' -f1)"
        else
            echo "Log file not found: $LOG_FILE"
        fi
        ;;
    
    "watch")
        echo "👀 Watching deployment monitor log (Ctrl+C to stop):"
        echo "=================================================="
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            echo "Log file not found: $LOG_FILE"
        fi
        ;;
    
    "archive")
        if [ -f "$LOG_FILE" ]; then
            ARCHIVE_NAME="deployment-monitor-$(date +%Y%m%d-%H%M%S).log"
            cp "$LOG_FILE" "/tmp/$ARCHIVE_NAME"
            echo "📦 Log archived as: /tmp/$ARCHIVE_NAME"
            echo "🗑️  Clearing current log..."
            > "$LOG_FILE"
            echo "✅ Current log cleared"
        else
            echo "Log file not found: $LOG_FILE"
        fi
        ;;
    
    *)
        echo "📋 Log Management Commands:"
        echo "=========================="
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  view [lines]    - View last N lines (default: 50)"
        echo "  clean           - Clean old logs and trim large files"
        echo "  info            - Show log file information"
        echo "  watch           - Watch log in real-time"
        echo "  archive         - Archive current log and start fresh"
        echo ""
        echo "Examples:"
        echo "  $0 view 100     - View last 100 lines"
        echo "  $0 clean        - Clean up old logs"
        echo "  $0 watch        - Watch logs in real-time"
        echo "  $0 info         - Show log file stats"
        ;;
esac
