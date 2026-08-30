#!/bin/bash
LOGFILE="/var/log/suricata/fast.log"
tail -F "$LOGFILE" | while read -r line; do
    if echo "$line" | grep -q "Possible Nmap SYN Scan"; then
        IP=$(echo "$line" | grep -oP '(?<=\{TCP\} )[0-9.]+')
        if [ -n "$IP" ]; then
            if ! iptables -C INPUT -s "$IP" -j DROP 2>/dev/null; then
                iptables -A INPUT -s "$IP" -j DROP
                echo "$(date): BLOCKED $IP" >> /root/blocked_ips.log
            fi
        fi
    fi
done
