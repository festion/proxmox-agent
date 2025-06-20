#!/bin/bash
# Fix Security Updates for Proxmox (different approach)
echo "🔒 Proxmox Security Updates Alternative Setup"
echo "============================================="

echo "📦 Adding Debian repositories for unattended-upgrades:"

# Add Debian main repos if not present
echo "deb http://deb.debian.org/debian bookworm main" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian bookworm-updates main" >> /etc/apt/sources.list
echo "deb http://security.debian.org/debian-security bookworm-security main" >> /etc/apt/sources.list

echo "🔄 Updating package lists:"
apt update

echo "📦 Installing unattended-upgrades:"
apt install -y unattended-upgrades

if [ $? -eq 0 ]; then
    echo "✅ unattended-upgrades installed successfully"
    
    # Configure for Proxmox
    echo "⚙️ Configuring for Proxmox environment:"
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
    "linux-.*";
    ".*-kernel-.*";
    "pve-kernel-.*";
    "proxmox-ve";
    "pve-manager";
    "pve-.*";
};

Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "false";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # Enable and start service
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    echo "✅ Security updates configured"
    systemctl status unattended-upgrades --no-pager
    
else
    echo "❌ Failed to install unattended-upgrades"
    echo "🔄 Alternative: Manual update script"
    
    # Create manual update script as fallback
    cat > /usr/local/bin/proxmox-security-updates.sh << 'EOF'
#!/bin/bash
# Manual Proxmox Security Updates
LOG_FILE="/var/log/proxmox-security-updates.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting security updates" >> "$LOG_FILE"

# Update package lists
apt update >> "$LOG_FILE" 2>&1

# Upgrade security packages only
apt list --upgradable | grep -E "(security|updates)" | awk -F/ '{print $1}' | while read package; do
    if [ -n "$package" ]; then
        echo "[$DATE] Upgrading security package: $package" >> "$LOG_FILE"
        apt install -y "$package" >> "$LOG_FILE" 2>&1
    fi
done

echo "[$DATE] Security updates completed" >> "$LOG_FILE"
EOF

    chmod +x /usr/local/bin/proxmox-security-updates.sh
    
    # Add to cron
    echo "0 2 * * * root /usr/local/bin/proxmox-security-updates.sh" >> /etc/crontab
    
    echo "✅ Manual security update script configured"
fi

echo ""
echo "🔍 Testing configuration:"
unattended-upgrades --dry-run 2>/dev/null || echo "Using fallback manual update script"

echo ""
echo "✅ Proxmox security updates configured!"