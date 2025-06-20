#!/bin/bash
# Verify and Fix SSH Key Authentication
echo "🔍 SSH KEY VERIFICATION AND REPAIR"
echo "=================================="

echo "1️⃣ Your local RSA public key:"
if [ -f ~/.ssh/id_rsa.pub ]; then
    cat ~/.ssh/id_rsa.pub
    echo ""
    echo "Fingerprint:"
    ssh-keygen -lf ~/.ssh/id_rsa.pub
else
    echo "❌ No RSA key found at ~/.ssh/id_rsa.pub"
    exit 1
fi

echo ""
echo "2️⃣ Current server authorized_keys content:"
ssh root@192.168.1.137 "cat /etc/pve/priv/authorized_keys"

echo ""
echo "3️⃣ Server authorized_keys fingerprints:"
ssh root@192.168.1.137 "ssh-keygen -lf /etc/pve/priv/authorized_keys"

echo ""
echo "4️⃣ Clearing and re-adding correct key:"
LOCAL_KEY=$(cat ~/.ssh/id_rsa.pub)

ssh root@192.168.1.137 "
echo '🔧 Replacing authorized_keys with correct client key'
cp /etc/pve/priv/authorized_keys /etc/pve/priv/authorized_keys.backup.\$(date +%Y%m%d-%H%M%S)
echo '# Claude Code SSH Key - Fixed $(date)' > /etc/pve/priv/authorized_keys
echo '$LOCAL_KEY' >> /etc/pve/priv/authorized_keys
chmod 600 /etc/pve/priv/authorized_keys
chown root:www-data /etc/pve/priv/authorized_keys
systemctl restart ssh
echo '✅ Key replacement completed'
echo 'New authorized_keys fingerprint:'
ssh-keygen -lf /etc/pve/priv/authorized_keys
"

echo ""
echo "5️⃣ Testing SSH key authentication:"
echo "Attempting connection with public key authentication only..."
if ssh -v -o PreferredAuthentications=publickey -o PasswordAuthentication=no root@192.168.1.137 "echo 'SSH key authentication successful!'" 2>&1 | grep -q "SSH key authentication successful"; then
    echo "✅ SSH key authentication now working!"
else
    echo "❌ SSH key authentication still failing"
    echo "Debug output:"
    ssh -v -o PreferredAuthentications=publickey -o PasswordAuthentication=no root@192.168.1.137 "echo 'test'" 2>&1 | tail -10
fi

echo ""
echo "🎯 SSH KEY VERIFICATION COMPLETED"
echo "================================"