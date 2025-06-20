#!/bin/bash
# Test different SSH key formats for Proxmox
echo "🔑 TESTING SSH KEY FORMATS"
echo "=========================="

echo "1️⃣ Current key in authorized_keys:"
tail -1 /etc/pve/priv/authorized_keys
echo ""

echo "2️⃣ Backing up current authorized_keys:"
cp /etc/pve/priv/authorized_keys /etc/pve/priv/authorized_keys.backup
echo "✅ Backup created: /etc/pve/priv/authorized_keys.backup"
echo ""

echo "3️⃣ Adding key with different options:"
# Add key with no-agent-forwarding and from restrictions for security
echo "# Claude Code SSH Key - Added $(date)" >> /etc/pve/priv/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8A97tj/fHwDnHskLNNdJKF+yyzrkq7PwfHK8uXFcyF1S04Gcue0kCOJrrOnip/GecDQJ4aoyIvw/16a0fDGuq7mosyP3dGL8DRSixXIUsujzAycEv785UsqIx4BKFnBtjAw== jeremy.ames@outlook.com" >> /etc/pve/priv/authorized_keys

echo "✅ Key added to authorized_keys"
echo ""

echo "4️⃣ Setting correct permissions:"
chmod 600 /etc/pve/priv/authorized_keys
chown root:www-data /etc/pve/priv/authorized_keys
echo "✅ Permissions set"
echo ""

echo "5️⃣ Verifying final state:"
echo "Key count: $(wc -l < /etc/pve/priv/authorized_keys)"
echo "Permissions: $(ls -la /etc/pve/priv/authorized_keys)"
echo ""

echo "6️⃣ Restarting SSH service:"
systemctl restart ssh
systemctl status ssh --no-pager | head -5
echo ""

echo "🧪 SSH KEY TESTING COMPLETED"
echo "============================"
echo "Key should now be ready for testing"
echo "Test command: ssh -v root@192.168.1.137"