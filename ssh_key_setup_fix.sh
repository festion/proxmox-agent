#!/bin/bash
# SSH Key Setup Fix for Proxmox
# Corrects the line break issue when adding SSH public key

echo "🔑 Setting up SSH key access for Proxmox"
echo "========================================"

# Method 1: Using heredoc to avoid line break issues
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8A97tj/fHwDnHskLNNdJKF+yyzrkq7PwfHK8uXFcyF1S04Gcue0kCOJrrOnip/GecDQJ4aoyIvw/16a0fDGuq7mosyP3dGL8DRSixXIUsujzAycEv785UsqIx4BKFnBtjAw== jeremy.ames@outlook.com
EOF

echo "✅ SSH key added successfully"

# Set proper permissions
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh/

echo "✅ SSH permissions set correctly"

# Verify the key was added
echo ""
echo "🔍 Verifying SSH key installation:"
echo "Number of keys in authorized_keys: $(wc -l < ~/.ssh/authorized_keys)"
echo "Last key added:"
tail -1 ~/.ssh/authorized_keys | cut -c1-50

echo ""
echo "✅ SSH key setup completed!"
echo "📋 You can now test SSH connection with key authentication"
echo "💡 Test command: ssh -i your_private_key root@192.168.1.137"