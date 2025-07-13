#!/bin/bash
# IO Delay and CPU Load Spike Monitor
# Monitors and analyzes IO delays and high load averages
# Based on findings: Load averages are high (2.26-4.40) on 4-core Intel N100

# Configuration
LOG_DIR="/var/log/proxmox-agent"
MAIN_LOG="$LOG_DIR/io-load-monitor.log"
ALERT_LOG="$LOG_DIR/load-alerts.log"
METRICS_LOG="$LOG_DIR/load-metrics.csv"

# Thresholds
LOAD_THRESHOLD_1MIN=3.0    # Alert if 1-min load > 3.0 (75% of cores)
LOAD_THRESHOLD_5MIN=2.5    # Alert if 5-min load > 2.5 
IO_WAIT_THRESHOLD=15       # Alert if iowait > 15%
HIGH_LOAD_THRESHOLD=4.0    # Critical alert if load > 4.0

# Email settings
EMAIL_ALERTS="admin@local"

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MAIN_LOG"
}

# Metrics logging function
log_metrics() {
    local timestamp="$1"
    local load1="$2"
    local load5="$3"
    local load15="$4"
    local iowait="$5"
    local cpu_util="$6"
    local memory_percent="$7"
    
    echo "$timestamp,$load1,$load5,$load15,$iowait,$cpu_util,$memory_percent" >> "$METRICS_LOG"
}

# Send alert function
send_alert() {
    local subject="$1"
    local message="$2"
    local priority="$3"
    
    log_message "ALERT [$priority]: $subject"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$priority] $subject: $message" >> "$ALERT_LOG"
    
    # Send email if available
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "Proxmox Alert: $subject" "$EMAIL_ALERTS"
    fi
    
    # Log to syslog
    logger -t proxmox-agent "[$priority] $subject: $message"
}

# Check if running on Proxmox
is_proxmox() {
    [ -f /etc/pve/nodes/proxmox/config ] || [ -f /etc/pve/cluster.conf ] || command -v pvesh >/dev/null 2>&1
}

# Get system metrics
get_system_metrics() {
    # Load averages
    local load_info=$(cat /proc/loadavg)
    local load1=$(echo $load_info | cut -d' ' -f1)
    local load5=$(echo $load_info | cut -d' ' -f2)
    local load15=$(echo $load_info | cut -d' ' -f3)
    
    # CPU and IO wait from vmstat
    local vmstat_info=$(vmstat 1 2 | tail -1)
    local user_cpu=$(echo $vmstat_info | awk '{print $13}')
    local system_cpu=$(echo $vmstat_info | awk '{print $14}')
    local idle_cpu=$(echo $vmstat_info | awk '{print $15}')
    local iowait=$(echo $vmstat_info | awk '{print $16}')
    
    # Calculate total CPU utilization
    local cpu_util=$(echo "100 - $idle_cpu" | bc -l 2>/dev/null || echo "N/A")
    
    # Memory utilization
    local mem_info=$(free | grep '^Mem:')
    local total_mem=$(echo $mem_info | awk '{print $2}')
    local used_mem=$(echo $mem_info | awk '{print $3}')
    local memory_percent=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc -l 2>/dev/null || echo "N/A")
    
    # Return values
    echo "$load1 $load5 $load15 $iowait $cpu_util $memory_percent"
}

# Analyze container/VM impact
analyze_vm_impact() {
    if is_proxmox; then
        log_message "Analyzing VM/Container impact on load:"
        
        # Get running VMs with high CPU usage
        local high_cpu_vms=$(pct list 2>/dev/null | awk 'NR>1 && $2=="running" {print $1}' | while read vmid; do
            local cpu_usage=$(pct status $vmid 2>/dev/null | grep -o 'cpu [0-9.]*' | cut -d' ' -f2)
            if [ ! -z "$cpu_usage" ] && [ $(echo "$cpu_usage > 0.1" | bc -l 2>/dev/null) = 1 ]; then
                local name=$(pct config $vmid 2>/dev/null | grep '^hostname:' | cut -d' ' -f2 || echo "Unknown")
                echo "LXC $vmid ($name): ${cpu_usage}% CPU"
            fi
        done)
        
        # Get QEMU VMs
        local qemu_vms=$(qm list 2>/dev/null | awk 'NR>1 && $3=="running" {print $1}' | while read vmid; do
            local name=$(qm config $vmid 2>/dev/null | grep '^name:' | cut -d' ' -f2 || echo "VM$vmid")
            echo "QEMU $vmid ($name): running"
        done)
        
        if [ ! -z "$high_cpu_vms" ]; then
            log_message "High CPU containers: $high_cpu_vms"
        fi
        
        if [ ! -z "$qemu_vms" ]; then
            log_message "Running VMs: $qemu_vms"
        fi
    fi
}

# Check storage IO
check_storage_io() {
    log_message "Checking storage IO performance:"
    
    if command -v iostat >/dev/null 2>&1; then
        # Get IO statistics
        local io_stats=$(iostat -x 1 1 | grep -E 'sda|sdb|nvme|dm-' | head -5)
        if [ ! -z "$io_stats" ]; then
            log_message "Storage IO stats:"
            echo "$io_stats" | while read line; do
                log_message "  $line"
            done
        fi
    else
        log_message "WARNING: iostat not available for detailed IO analysis"
    fi
    
    # Check disk usage and potential issues
    local disk_usage=$(df -h | grep -E '/(|mnt|var)' | awk '$5 > 80 {print $0}')
    if [ ! -z "$disk_usage" ]; then
        log_message "High disk usage detected:"
        echo "$disk_usage" | while read line; do
            log_message "  $line"
        done
    fi
}

# Check processes contributing to load
check_high_load_processes() {
    log_message "Top processes by CPU usage:"
    ps aux --sort=-%cpu | head -10 | while read line; do
        log_message "  $line"
    done
    
    log_message "Processes in uninterruptible sleep (D state):"
    local d_state_procs=$(ps aux | awk '$8 ~ /D/ {print $2, $11}')
    if [ ! -z "$d_state_procs" ]; then
        echo "$d_state_procs" | while read line; do
            log_message "  PID: $line"
        done
    else
        log_message "  No processes in D state found"
    fi
}

# Main monitoring function
monitor_system() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    log_message "=== System Load and IO Monitor - $timestamp ==="
    
    # Get current metrics
    local metrics=$(get_system_metrics)
    local load1=$(echo $metrics | cut -d' ' -f1)
    local load5=$(echo $metrics | cut -d' ' -f2)
    local load15=$(echo $metrics | cut -d' ' -f3)
    local iowait=$(echo $metrics | cut -d' ' -f4)
    local cpu_util=$(echo $metrics | cut -d' ' -f5)
    local memory_percent=$(echo $metrics | cut -d' ' -f6)
    
    log_message "Load averages: $load1 (1m), $load5 (5m), $load15 (15m)"
    log_message "CPU utilization: $cpu_util%, IO wait: $iowait%"
    log_message "Memory usage: $memory_percent%"
    
    # Log metrics to CSV
    log_metrics "$timestamp" "$load1" "$load5" "$load15" "$iowait" "$cpu_util" "$memory_percent"
    
    # Check thresholds and send alerts
    if [ $(echo "$load1 > $HIGH_LOAD_THRESHOLD" | bc -l 2>/dev/null) = 1 ]; then
        send_alert "CRITICAL Load Average" "1-minute load average is $load1 (threshold: $HIGH_LOAD_THRESHOLD)" "CRITICAL"
        analyze_vm_impact
        check_high_load_processes
        check_storage_io
    elif [ $(echo "$load1 > $LOAD_THRESHOLD_1MIN" | bc -l 2>/dev/null) = 1 ]; then
        send_alert "High Load Average" "1-minute load average is $load1 (threshold: $LOAD_THRESHOLD_1MIN)" "WARNING"
    fi
    
    if [ $(echo "$load5 > $LOAD_THRESHOLD_5MIN" | bc -l 2>/dev/null) = 1 ]; then
        send_alert "Sustained High Load" "5-minute load average is $load5 (threshold: $LOAD_THRESHOLD_5MIN)" "WARNING"
    fi
    
    if [ $(echo "$iowait > $IO_WAIT_THRESHOLD" | bc -l 2>/dev/null) = 1 ]; then
        send_alert "High IO Wait" "IO wait time is $iowait% (threshold: $IO_WAIT_THRESHOLD%)" "WARNING"
        check_storage_io
    fi
    
    log_message "=== Monitor cycle complete ==="
    echo ""
}

# Install iostat if not available
install_iostat() {
    if ! command -v iostat >/dev/null 2>&1; then
        log_message "Installing iostat (sysstat package)..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y sysstat
        elif command -v yum >/dev/null 2>&1; then
            yum install -y sysstat
        else
            log_message "WARNING: Cannot install sysstat - please install manually"
        fi
    fi
}

# Show recent trends
show_trends() {
    log_message "=== Recent Load Trends ==="
    
    if [ -f "$METRICS_LOG" ]; then
        echo "Timestamp,Load1m,Load5m,Load15m,IOWait%,CPU%,Memory%"
        tail -20 "$METRICS_LOG"
    else
        log_message "No metrics history available yet"
    fi
    
    if [ -f "$ALERT_LOG" ]; then
        log_message "=== Recent Alerts ==="
        tail -10 "$ALERT_LOG"
    fi
}

# Usage information
usage() {
    echo "Usage: $0 [monitor|trends|install-deps|help]"
    echo "  monitor      - Run single monitoring cycle"
    echo "  trends       - Show recent trends and alerts"
    echo "  install-deps - Install required dependencies"
    echo "  help         - Show this help"
}

# Main execution
case "${1:-monitor}" in
    "monitor")
        monitor_system
        ;;
    "trends")
        show_trends
        ;;
    "install-deps")
        install_iostat
        ;;
    "help")
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac