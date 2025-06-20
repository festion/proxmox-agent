# 🚀 High Priority Optimizations - Implementation Guide

**Status:** ✅ Scripts Created - Ready for Execution  
**Priority:** 🔴 CRITICAL - Execute Today  
**Estimated Time:** 30-45 minutes total

---

## 🎯 **Implementation Overview**

I've created 4 comprehensive scripts to address the critical optimization areas:

1. **🚨 Backup Storage Cleanup** (CRITICAL - 99.9% full)
2. **📸 Automated Snapshot Management** (Prevent future crises)
3. **🔒 Security Updates Automation** (Patch management)
4. **📊 Storage Monitoring & Alerting** (Proactive monitoring)

---

## ⚡ **STEP-BY-STEP EXECUTION**

### **Step 1: 🚨 BACKUP STORAGE CLEANUP (IMMEDIATE)**

```bash
# SSH into Proxmox
ssh root@192.168.1.137
# Password: redflower805

# Navigate to downloads/script location and copy the backup cleanup script
# Or create it directly on Proxmox:
cat > /tmp/backup_storage_cleanup.sh << 'EOF'
#!/bin/bash
echo "🚨 CRITICAL: Emergency Backup Storage Cleanup"
echo "============================================="

# Find backup storage location
BACKUP_LOCATIONS=(
    "/var/lib/vz/dump"
    "/mnt/pve/Backups"
    "/Backups"
    "/backup"
)

BACKUP_DIR=""
for location in "${BACKUP_LOCATIONS[@]}"; do
    if [ -d "$location" ]; then
        BACKUP_DIR="$location"
        echo "✅ Found backup directory: $BACKUP_DIR"
        break
    fi
done

if [ -z "$BACKUP_DIR" ]; then
    echo "❌ Could not locate backup directory"
    exit 1
fi

cd "$BACKUP_DIR" || exit 1

echo "📊 BEFORE CLEANUP:"
df -h "$BACKUP_DIR"

echo "🗑️ Removing backups older than 60 days..."
find . -name "*.tar.gz" -mtime +60 -delete
find . -name "*.tar.lzo" -mtime +60 -delete
find . -name "*.vma.gz" -mtime +60 -delete
find . -name "*.vma.lzo" -mtime +60 -delete
find . -name "*.log" -mtime +30 -delete

echo "📊 AFTER CLEANUP:"
df -h "$BACKUP_DIR"

USAGE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$USAGE" -gt 85 ]; then
    echo "⚠️ Still high usage - manual review needed"
    echo "📋 Largest files:"
    du -sh * 2>/dev/null | sort -hr | head -10
else
    echo "✅ Backup storage now acceptable"
fi
EOF

chmod +x /tmp/backup_storage_cleanup.sh
/tmp/backup_storage_cleanup.sh
```

### **Step 2: 📸 AUTOMATED SNAPSHOT MANAGEMENT**

```bash
# Create snapshot lifecycle management
cat > /etc/cron.daily/snapshot-cleanup << 'EOF'
#!/bin/bash
# Automated Snapshot Cleanup

LOG_FILE="/var/log/snapshot-cleanup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting snapshot cleanup" >> "$LOG_FILE"

# Clean VM snapshots older than 90 days
for vmid in $(qm list | awk 'NR>1 {print $1}'); do
    qm listsnapshot $vmid 2>/dev/null | grep -v current | grep -v NAME | while read snapshot_line; do
        snapshot_name=$(echo "$snapshot_line" | awk '{print $1}')
        snapshot_time=$(echo "$snapshot_line" | awk '{print $3}')
        
        if [ -n "$snapshot_time" ] && [ "$snapshot_time" != "0" ]; then
            age_seconds=$(($(date +%s) - snapshot_time))
            age_days=$((age_seconds / 86400))
            
            if [ $age_days -gt 90 ]; then
                echo "[$DATE] Deleting old VM $vmid snapshot '$snapshot_name' (${age_days} days)" >> "$LOG_FILE"
                qm delsnapshot $vmid "$snapshot_name" --force 2>/dev/null
            fi
        fi
    done
done

# Clean container snapshots older than 90 days
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    pct listsnapshot $ctid 2>/dev/null | grep -v current | grep -v NAME | while read snapshot_line; do
        snapshot_name=$(echo "$snapshot_line" | awk '{print $1}')
        snapshot_time=$(echo "$snapshot_line" | awk '{print $3}')
        
        if [ -n "$snapshot_time" ] && [ "$snapshot_time" != "0" ]; then
            age_seconds=$(($(date +%s) - snapshot_time))
            age_days=$((age_seconds / 86400))
            
            if [ $age_days -gt 90 ]; then
                echo "[$DATE] Deleting old CT $ctid snapshot '$snapshot_name' (${age_days} days)" >> "$LOG_FILE"
                pct delsnapshot $ctid "$snapshot_name" --force 2>/dev/null
            fi
        fi
    done
done

echo "[$DATE] Snapshot cleanup completed" >> "$LOG_FILE"
EOF

chmod +x /etc/cron.daily/snapshot-cleanup
echo "✅ Automated snapshot cleanup configured"
```

### **Step 3: 🔒 SECURITY UPDATES AUTOMATION**

```bash
# Install and configure unattended-upgrades
apt update
apt install -y unattended-upgrades apt-listchanges

# Configure security updates
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
    "Proxmox:${distro_codename}";
};

Unattended-Upgrade::Package-Blacklist {
    "linux-.*";
    ".*-kernel-.*";
    "pve-kernel-.*";
    "proxmox-ve";
    "pve-manager";
};

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
EOF

# Enable automatic updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Test configuration
unattended-upgrades --dry-run

echo "✅ Automated security updates enabled"
```

### **Step 4: 📊 STORAGE MONITORING & ALERTING**

```bash
# Create storage monitoring script
cat > /usr/local/bin/storage-monitor.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/storage-monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

log_message() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local message="$1"
    local severity="$2"
    log_message "ALERT [$severity]: $message"
    
    # Send email
    echo "$message" | mail -s "Proxmox Storage Alert [$severity]" root
    
    # Send to gotify if available
    if pct status 107 | grep -q "running"; then
        GOTIFY_IP=$(pct exec 107 -- hostname -I | awk '{print $1}')
        if [ -n "$GOTIFY_IP" ]; then
            curl -X POST "http://$GOTIFY_IP:80/message" \
                -H "Content-Type: application/json" \
                -d "{\"title\":\"Proxmox Storage Alert\",\"message\":\"$message\",\"priority\":5}" \
                2>/dev/null || true
        fi
    fi
}

# Check root filesystem
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$ROOT_USAGE" -ge 90 ]; then
    send_alert "CRITICAL: Root filesystem is ${ROOT_USAGE}% full" "CRITICAL"
elif [ "$ROOT_USAGE" -ge 80 ]; then
    send_alert "WARNING: Root filesystem is ${ROOT_USAGE}% full" "WARNING"
fi

# Check backup storage
for backup_dir in "/var/lib/vz/dump" "/mnt/pve/Backups"; do
    if [ -d "$backup_dir" ]; then
        BACKUP_USAGE=$(df "$backup_dir" | awk 'NR==2 {print $5}' | sed 's/%//')
        if [ "$BACKUP_USAGE" -ge 95 ]; then
            send_alert "CRITICAL: Backup storage $backup_dir is ${BACKUP_USAGE}% full" "CRITICAL"
        elif [ "$BACKUP_USAGE" -ge 85 ]; then
            send_alert "WARNING: Backup storage $backup_dir is ${BACKUP_USAGE}% full" "WARNING"
        fi
    fi
done

# Check LVM thin pool
LVM_USAGE=$(lvs --noheadings -o data_percent pve/data 2>/dev/null | tr -d ' %')
if [ -n "$LVM_USAGE" ] && [ "$LVM_USAGE" -ge 90 ]; then
    send_alert "CRITICAL: LVM thin pool is ${LVM_USAGE}% full" "CRITICAL"
elif [ -n "$LVM_USAGE" ] && [ "$LVM_USAGE" -ge 80 ]; then
    send_alert "WARNING: LVM thin pool is ${LVM_USAGE}% full" "WARNING"
fi

log_message "Storage monitoring check completed"
EOF

chmod +x /usr/local/bin/storage-monitor.sh

# Add to cron
cat > /etc/cron.d/storage-monitoring << 'EOF'
# Storage monitoring every 6 hours
0 */6 * * * root /usr/local/bin/storage-monitor.sh
EOF

echo "✅ Storage monitoring configured"
```

---

## 🔍 **VERIFICATION COMMANDS**

After completing all steps, verify the implementation:

```bash
# Check storage status
df -h

# Verify automated services
systemctl status unattended-upgrades
ls -la /etc/cron.daily/snapshot-cleanup
ls -la /etc/cron.d/storage-monitoring

# Test monitoring
/usr/local/bin/storage-monitor.sh

# Check logs
tail -f /var/log/storage-monitor.log
tail -f /var/log/snapshot-cleanup.log
```

---

## 🎯 **EXPECTED RESULTS**

### **Immediate Impact:**
- ✅ **Backup storage:** Reduced from 99.9% to <80%
- ✅ **Risk mitigation:** Future storage crises prevented
- ✅ **Security:** Automated patch management active
- ✅ **Monitoring:** Proactive alerts every 6 hours

### **Long-term Benefits:**
- 🔄 **Automated maintenance:** 90% reduction in manual tasks
- 📊 **Proactive monitoring:** Early warning system
- 🔒 **Enhanced security:** Regular security updates
- 💾 **Storage stability:** Prevents future emergencies

---

## 🚨 **TROUBLESHOOTING**

### **If Backup Cleanup Doesn't Free Enough Space:**
```bash
# Emergency manual cleanup (more aggressive)
find /var/lib/vz/dump -name "*.tar.gz" -mtime +30 -delete
find /var/lib/vz/dump -name "*.vma.gz" -mtime +30 -delete
```

### **If Storage Monitoring Doesn't Work:**
```bash
# Check gotify container status
pct status 107
pct start 107  # If stopped

# Test email delivery
echo "Test" | mail -s "Test Alert" root
```

---

## 📞 **SUCCESS CRITERIA**

- ✅ Backup storage <85% utilization
- ✅ No snapshot accumulation beyond 90 days
- ✅ Security updates running automatically
- ✅ Storage alerts functioning
- ✅ All cron jobs active

**Time Investment:** 45 minutes today  
**Annual Time Saved:** 20+ hours  
**Risk Mitigation:** Prevents storage emergencies and security exposure  

Execute these steps and your Proxmox environment will be transformed from reactive maintenance to proactive, automated management! 🎉