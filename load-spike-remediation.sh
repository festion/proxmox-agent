#!/bin/bash
# Load Spike Remediation Script
# Automatically addresses high CPU load and IO delays on Proxmox

# Configuration
LOAD_CRITICAL=4.0
LOAD_WARNING=3.0
IO_WAIT_CRITICAL=20
CONTAINER_CPU_LIMIT=80    # Percentage
VM_CPU_LIMIT=85          # Percentage

LOG_FILE="/var/log/proxmox-agent/remediation.log"
BACKUP_DIR="/var/log/proxmox-agent/backups"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")" "$BACKUP_DIR"

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if running on Proxmox
is_proxmox() {
    [ -f /etc/pve/nodes/proxmox/config ] || [ -f /etc/pve/cluster.conf ] || command -v pvesh >/dev/null 2>&1
}

# Get current system load
get_load_average() {
    cat /proc/loadavg | cut -d' ' -f1
}

# Get IO wait percentage
get_io_wait() {
    vmstat 1 2 | tail -1 | awk '{print $16}'
}

# Check for high-CPU containers
check_container_cpu() {
    log_action "Checking container CPU usage..."
    
    if ! is_proxmox; then
        log_action "Not running on Proxmox, skipping container checks"
        return 0
    fi
    
    local high_cpu_containers=()
    
    # Check LXC containers
    pct list 2>/dev/null | awk 'NR>1 && $2=="running" {print $1}' | while read vmid; do
        local cpu_info=$(pct status $vmid 2>/dev/null | grep 'cpu')
        if [ ! -z "$cpu_info" ]; then
            local cpu_percent=$(echo "$cpu_info" | grep -o '[0-9.]*' | head -1)
            if [ ! -z "$cpu_percent" ] && [ $(echo "$cpu_percent > $CONTAINER_CPU_LIMIT" | bc -l 2>/dev/null) = 1 ]; then
                local name=$(pct config $vmid 2>/dev/null | grep '^hostname:' | cut -d' ' -f2 || echo "Unknown")
                log_action "High CPU container found: $vmid ($name) - ${cpu_percent}%"
                
                # Check if container can be optimized
                optimize_container $vmid "$name" "$cpu_percent"
            fi
        fi
    done
}

# Optimize high-CPU container
optimize_container() {
    local vmid="$1"
    local name="$2"
    local cpu_percent="$3"
    
    log_action "Optimizing container $vmid ($name)..."
    
    # Backup current configuration
    pct config $vmid > "$BACKUP_DIR/container_${vmid}_config_$(date +%Y%m%d_%H%M%S).conf" 2>/dev/null
    
    # Check current CPU limit
    local current_cpulimit=$(pct config $vmid 2>/dev/null | grep '^cpulimit:' | cut -d' ' -f2)
    
    if [ -z "$current_cpulimit" ] || [ "$current_cpulimit" = "0" ]; then
        # No CPU limit set, apply conservative limit
        log_action "Setting CPU limit for container $vmid to 75%"
        pct set $vmid --cpulimit 0.75 2>/dev/null || log_action "Failed to set CPU limit for $vmid"
    else
        # CPU limit exists, check if it needs adjustment
        local new_limit=$(echo "$current_cpulimit * 0.9" | bc -l)
        log_action "Reducing CPU limit for container $vmid from $current_cpulimit to $new_limit"
        pct set $vmid --cpulimit $new_limit 2>/dev/null || log_action "Failed to adjust CPU limit for $vmid"
    fi
    
    # Check for specific optimization opportunities based on container type
    local container_tags=$(pct config $vmid 2>/dev/null | grep '^tags:' | cut -d' ' -f2-)
    if echo "$container_tags" | grep -q "development"; then
        log_action "Development container detected - considering resource optimization"
        # Could pause non-essential development containers during high load
    fi
}

# Check for high-CPU VMs
check_vm_cpu() {
    log_action "Checking VM CPU usage..."
    
    if ! is_proxmox; then
        return 0
    fi
    
    qm list 2>/dev/null | awk 'NR>1 && $3=="running" {print $1}' | while read vmid; do
        local name=$(qm config $vmid 2>/dev/null | grep '^name:' | cut -d' ' -f2 || echo "VM$vmid")
        
        # Get VM CPU usage (this is more complex for QEMU VMs)
        # For now, just log and suggest manual investigation
        log_action "Running VM detected: $vmid ($name) - requires manual CPU investigation"
    done
}

# Optimize kernel parameters for IO performance
optimize_kernel_io() {
    log_action "Optimizing kernel IO parameters..."
    
    # Backup current settings
    sysctl -a | grep -E "(vm\.|kernel\.)" > "$BACKUP_DIR/sysctl_backup_$(date +%Y%m%d_%H%M%S).conf" 2>/dev/null
    
    # Optimize for better IO performance under load
    sysctl vm.dirty_ratio=10 2>/dev/null || log_action "Failed to set vm.dirty_ratio"
    sysctl vm.dirty_background_ratio=5 2>/dev/null || log_action "Failed to set vm.dirty_background_ratio"
    sysctl vm.dirty_expire_centisecs=12000 2>/dev/null || log_action "Failed to set vm.dirty_expire_centisecs"
    sysctl vm.dirty_writeback_centisecs=1500 2>/dev/null || log_action "Failed to set vm.dirty_writeback_centisecs"
    
    # Adjust I/O scheduler if possible
    for disk in $(lsblk -nd -o NAME | grep -E '^(sd|nvme)'); do
        if [ -f "/sys/block/$disk/queue/scheduler" ]; then
            current_scheduler=$(cat "/sys/block/$disk/queue/scheduler" | grep -o '\[.*\]' | tr -d '[]')
            log_action "Current scheduler for $disk: $current_scheduler"
            
            # For SSDs, try mq-deadline or none
            if echo "mq-deadline" > "/sys/block/$disk/queue/scheduler" 2>/dev/null; then
                log_action "Set mq-deadline scheduler for $disk"
            fi
        fi
    done
}

# Clean up processes consuming excessive resources
cleanup_processes() {
    log_action "Checking for resource-heavy processes..."
    
    # Find processes with high CPU usage (excluding kernel threads)
    local high_cpu_procs=$(ps aux --sort=-%cpu | awk 'NR>1 && $3>50 && $11!~/^\[.*\]$/ {print $2,$3,$11}' | head -5)
    
    if [ ! -z "$high_cpu_procs" ]; then
        log_action "High CPU processes found:"
        echo "$high_cpu_procs" | while read pid cpu cmd; do
            log_action "  PID $pid: $cmd ($cpu% CPU)"
            
            # Be conservative - only suggest action, don't automatically kill
            case "$cmd" in
                *backup*|*rsync*|*cp*)
                    log_action "    Backup/copy process detected - may be legitimate"
                    ;;
                *compile*|*make*|*gcc*)
                    log_action "    Compilation process detected - consider reducing priority"
                    renice 10 $pid 2>/dev/null && log_action "    Reduced priority for PID $pid"
                    ;;
                *)
                    log_action "    Unknown high-CPU process - manual investigation recommended"
                    ;;
            esac
        done
    fi
    
    # Check for processes in uninterruptible sleep (D state)
    local d_state_count=$(ps aux | awk '$8 ~ /D/ {print $2}' | wc -l)
    if [ "$d_state_count" -gt 0 ]; then
        log_action "Found $d_state_count processes in uninterruptible sleep (may indicate IO issues)"
        ps aux | awk '$8 ~ /D/ {print $2,$11}' | while read pid cmd; do
            log_action "  D-state PID $pid: $cmd"
        done
    fi
}

# Emergency load reduction
emergency_load_reduction() {
    log_action "EMERGENCY: Implementing aggressive load reduction measures"
    
    # Stop non-essential services temporarily
    local services_to_pause=("cron" "postfix")
    
    for service in "${services_to_pause[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_action "Temporarily stopping $service"
            systemctl stop "$service" && echo "$service" >> "$BACKUP_DIR/stopped_services_$(date +%Y%m%d_%H%M%S).list"
        fi
    done
    
    # Pause development containers if any
    if is_proxmox; then
        pct list 2>/dev/null | awk 'NR>1 && $2=="running" {print $1}' | while read vmid; do
            local tags=$(pct config $vmid 2>/dev/null | grep '^tags:' | cut -d' ' -f2- || echo "")
            if echo "$tags" | grep -qi "development\|testing\|non-production"; then
                local name=$(pct config $vmid 2>/dev/null | grep '^hostname:' | cut -d' ' -f2 || echo "Unknown")
                log_action "Pausing development container $vmid ($name) due to emergency load"
                pct suspend $vmid 2>/dev/null && echo "$vmid" >> "$BACKUP_DIR/suspended_containers_$(date +%Y%m%d_%H%M%S).list"
            fi
        done
    fi
    
    log_action "Emergency measures applied. Monitor system and restore services when load decreases."
}

# Restore services after load reduction
restore_services() {
    log_action "Restoring services after load reduction..."
    
    # Find most recent stopped services list
    local services_file=$(ls -t "$BACKUP_DIR"/stopped_services_*.list 2>/dev/null | head -1)
    if [ -f "$services_file" ]; then
        while read service; do
            log_action "Restoring service: $service"
            systemctl start "$service" 2>/dev/null || log_action "Failed to restore $service"
        done < "$services_file"
    fi
    
    # Find most recent suspended containers list
    local containers_file=$(ls -t "$BACKUP_DIR"/suspended_containers_*.list 2>/dev/null | head -1)
    if [ -f "$containers_file" ] && is_proxmox; then
        while read vmid; do
            log_action "Resuming container: $vmid"
            pct resume "$vmid" 2>/dev/null || log_action "Failed to resume container $vmid"
        done < "$containers_file"
    fi
}

# Main remediation logic
main_remediation() {
    local load=$(get_load_average)
    local io_wait=$(get_io_wait)
    
    log_action "=== Load Spike Remediation - $(date) ==="
    log_action "Current load: $load, IO wait: $io_wait%"
    
    # Determine severity and action
    if [ $(echo "$load > $LOAD_CRITICAL" | bc -l 2>/dev/null) = 1 ] || [ $(echo "$io_wait > $IO_WAIT_CRITICAL" | bc -l 2>/dev/null) = 1 ]; then
        log_action "CRITICAL load detected - implementing emergency measures"
        emergency_load_reduction
        optimize_kernel_io
        cleanup_processes
    elif [ $(echo "$load > $LOAD_WARNING" | bc -l 2>/dev/null) = 1 ]; then
        log_action "WARNING load detected - implementing standard optimizations"
        check_container_cpu
        check_vm_cpu
        optimize_kernel_io
        cleanup_processes
    else
        log_action "Load within acceptable limits - performing maintenance optimizations"
        optimize_kernel_io
    fi
    
    log_action "=== Remediation complete ==="
}

# Usage
usage() {
    echo "Usage: $0 [remediate|restore|status]"
    echo "  remediate - Run load spike remediation"
    echo "  restore   - Restore services after emergency measures"
    echo "  status    - Show current system status"
}

case "${1:-remediate}" in
    "remediate")
        main_remediation
        ;;
    "restore")
        restore_services
        ;;
    "status")
        echo "Current load: $(get_load_average)"
        echo "IO wait: $(get_io_wait)%"
        echo "Recent actions:"
        tail -10 "$LOG_FILE" 2>/dev/null || echo "No log file found"
        ;;
    *)
        usage
        exit 1
        ;;
esac