#!/bin/bash
# Debug SSH Key Setup for Proxmox
echo "🔍 SSH Key Setup Diagnostics"
echo "============================"

echo "1. Checking SSH directory structure:"
ls -la ~/.ssh/

echo ""
echo "2. Checking authorized_keys file:"
if [ -f ~/.ssh/authorized_keys ]; then
    echo "File exists, permissions: $(ls -la ~/.ssh/authorized_keys)"
    echo "Number of keys: $(wc -l < ~/.ssh/authorized_keys)"
    echo "Last key entry:"
    tail -1 ~/.ssh/authorized_keys
else
    echo "❌ authorized_keys file does not exist"
    echo "Creating ~/.ssh/authorized_keys..."
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
fi

echo ""
echo "3. SSH daemon configuration check:"
grep -E "(PubkeyAuthentication|PasswordAuthentication|PermitRootLogin)" /etc/ssh/sshd_config | grep -v "^#"

echo ""
echo "4. Adding SSH key with proper format:"
# Ensure the key is on a single line
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8A97tj/fHwDnHskLNNdJKF+yyzrkq7PwfHK8uXFcyF1S04Gcue0kCOJrrOnip/GecDQJ4aoyIvw/16a0fDGuq7mosyP3dGL8DRSixXIUsujzAycEv785UsqIx4BKFnBtjAw== jeremy.ames@outlook.com
EOF

echo ""
echo "5. Setting correct permissions:"
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown root:root ~/.ssh
chown root:root ~/.ssh/authorized_keys

echo ""
echo "6. Final verification:"
ls -la ~/.ssh/
echo "Key count: $(wc -l < ~/.ssh/authorized_keys)"

echo ""
echo "7. Testing SSH configuration:"
sshd -t && echo "✅ SSH config is valid" || echo "❌ SSH config has errors"

echo ""
echo "✅ SSH key setup completed!"
echo "🔍 If SSH still doesn't work, check:"
echo "   - SSH daemon is running: systemctl status ssh"
echo "   - Firewall allows SSH: iptables -L | grep ssh"
echo "   - SSH logs: tail -f /var/log/auth.log"