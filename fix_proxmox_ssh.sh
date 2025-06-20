#!/bin/bash
# Fix SSH access for Proxmox (uses /etc/pve/priv/authorized_keys)
echo "🔧 Fixing Proxmox SSH Key Access"
echo "================================"

echo "📍 Proxmox stores SSH keys in: /etc/pve/priv/authorized_keys"
echo "Current keys in file:"
wc -l /etc/pve/priv/authorized_keys

echo ""
echo "🔑 Adding SSH key to Proxmox authorized_keys:"
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8A97tj/fHwDnHskLNNdJKF+yyzrkq7PwfHK8uXFcyF1S04Gcue0kCOJrrOnip/GecDQJ4aoyIvw/16a0fDGuq7mosyP3dGL8DRSixXIUsujzAycEv785UsqIx4BKFnBtjAw== jeremy.ames@outlook.com' >> /etc/pve/priv/authorized_keys

echo "✅ Key added. New key count: $(wc -l < /etc/pve/priv/authorized_keys)"

echo ""
echo "🔒 Setting proper permissions:"
chmod 600 /etc/pve/priv/authorized_keys
ls -la /etc/pve/priv/authorized_keys

echo ""
echo "✅ SSH key setup for Proxmox completed!"
echo "🧪 Test with: ssh -i your_private_key root@192.168.1.137"