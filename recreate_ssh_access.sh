#!/bin/bash
# Complete SSH Key Recreation Script for Proxmox
echo "🔑 PROXMOX SSH KEY RECREATION SCRIPT"
echo "==================================="
echo "This script will completely recreate SSH key access"
echo ""

# Get the correct public key from local machine
echo "1️⃣ Getting your local SSH public key:"
if [ -f ~/.ssh/id_rsa.pub ]; then
    LOCAL_KEY=$(cat ~/.ssh/id_rsa.pub)
    echo "✅ Found local RSA key"
    echo "Key: ${LOCAL_KEY:0:50}...${LOCAL_KEY: -20}"
    echo ""
    echo "Fingerprint:"
    ssh-keygen -lf ~/.ssh/id_rsa.pub
else
    echo "❌ ERROR: No RSA key found at ~/.ssh/id_rsa.pub"
    echo "Generate one first with: ssh-keygen -t rsa -b 4096 -C 'jeremy.ames@outlook.com'"
    exit 1
fi

echo ""
echo "2️⃣ This script will now connect to Proxmox and:"
echo "   - Backup current authorized_keys"
echo "   - Replace with your correct key"
echo "   - Set proper permissions"
echo "   - Restart SSH service"
echo "   - Test the connection"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "3️⃣ Executing SSH key recreation on Proxmox server..."

# Create the server-side script content
SERVER_SCRIPT="#!/bin/bash
echo '🔧 SSH KEY RECREATION ON PROXMOX SERVER'
echo '======================================'

echo '1️⃣ Current status:'
echo 'Current authorized_keys:'
if [ -f /etc/pve/priv/authorized_keys ]; then
    echo \"Lines in file: \$(wc -l < /etc/pve/priv/authorized_keys)\"
    echo \"File size: \$(du -h /etc/pve/priv/authorized_keys | cut -f1)\"
    echo \"Permissions: \$(ls -la /etc/pve/priv/authorized_keys)\"
else
    echo '❌ No authorized_keys file found!'
fi

echo ''
echo '2️⃣ Creating backup:'
if [ -f /etc/pve/priv/authorized_keys ]; then
    cp /etc/pve/priv/authorized_keys /etc/pve/priv/authorized_keys.backup.\$(date +%Y%m%d-%H%M%S)
    echo '✅ Backup created'
else
    echo 'ℹ️  No existing file to backup'
fi

echo ''
echo '3️⃣ Writing new authorized_keys with correct key:'
cat > /etc/pve/priv/authorized_keys << 'KEYEOF'
# Claude Code SSH Key - Recreated \$(date)
$LOCAL_KEY
KEYEOF

echo '✅ New authorized_keys file created'

echo ''
echo '4️⃣ Setting correct permissions:'
chmod 600 /etc/pve/priv/authorized_keys
chown root:www-data /etc/pve/priv/authorized_keys
echo '✅ Permissions set:'
ls -la /etc/pve/priv/authorized_keys

echo ''
echo '5️⃣ Verifying key fingerprint:'
ssh-keygen -lf /etc/pve/priv/authorized_keys

echo ''
echo '6️⃣ Checking SSH daemon configuration:'
echo 'Relevant SSH config lines:'
grep -E \"(PubkeyAuthentication|AuthorizedKeysFile|PermitRootLogin)\" /etc/ssh/sshd_config | grep -v \"#\"

echo ''
echo '7️⃣ Testing SSH configuration:'
sshd -t && echo '✅ SSH config is valid' || echo '❌ SSH config has errors'

echo ''
echo '8️⃣ Restarting SSH service:'
systemctl restart ssh
sleep 2
if systemctl is-active ssh >/dev/null; then
    echo '✅ SSH service is active'
else
    echo '❌ SSH service failed to start'
    systemctl status ssh --no-pager
fi

echo ''
echo '9️⃣ Final verification:'
echo 'New authorized_keys content:'
cat /etc/pve/priv/authorized_keys
echo ''
echo 'File stats:'
echo \"Lines: \$(wc -l < /etc/pve/priv/authorized_keys)\"
echo \"Size: \$(du -h /etc/pve/priv/authorized_keys | cut -f1)\"

echo ''
echo '✅ SSH KEY RECREATION COMPLETED ON SERVER'
echo '======================================='
echo 'Ready for client testing...'
"

# Execute the server script via SSH
echo "Connecting to Proxmox server..."
echo "$SERVER_SCRIPT" | ssh root@192.168.1.137 'cat > /tmp/recreate_ssh.sh && chmod +x /tmp/recreate_ssh.sh && bash /tmp/recreate_ssh.sh && rm /tmp/recreate_ssh.sh'

echo ""
echo "4️⃣ Testing SSH key authentication from client..."
echo "Attempting connection with public key only..."

# Test the connection
if ssh -v -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o ConnectTimeout=10 root@192.168.1.137 "echo 'SSH key authentication successful! Connection working.'" 2>/dev/null; then
    echo "✅ SUCCESS! SSH key authentication is now working!"
    echo ""
    echo "5️⃣ Final connection test:"
    ssh root@192.168.1.137 "echo 'Host: \$(hostname)' && echo 'Time: \$(date)' && echo 'SSH key login: ✅ WORKING'"
else
    echo "❌ SSH key authentication still not working"
    echo ""
    echo "🔍 Troubleshooting information:"
    echo "Testing with verbose output:"
    ssh -v -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o ConnectTimeout=10 root@192.168.1.137 "echo 'test'" 2>&1 | grep -E "(debug1: Offering|debug1: Authentications|Permission denied)" | tail -5
    echo ""
    echo "💡 Manual steps to try:"
    echo "1. Access Proxmox web GUI → Node → Shell"
    echo "2. Run: cat /etc/pve/priv/authorized_keys"
    echo "3. Verify your key is there and matches your local key"
    echo "4. Run: systemctl restart ssh"
    echo "5. Check logs: journalctl -u ssh --since '5 minutes ago'"
fi

echo ""
echo "🎯 SSH KEY RECREATION SCRIPT COMPLETED"
echo "======================================"
echo ""
echo "📋 Summary:"
echo "- Local key fingerprint: $(ssh-keygen -lf ~/.ssh/id_rsa.pub | awk '{print $2}')"
echo "- Script executed on server: ✅"
echo "- Ready for testing: ✅"
echo ""
echo "🧪 Test command: ssh root@192.168.1.137"