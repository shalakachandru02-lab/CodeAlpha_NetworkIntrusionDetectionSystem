# CodeAlpha_NetworkIntrusionDetectionSystem

A network-based Intrusion Detection System (IDS) built using **Suricata**, configured with custom detection rules, live traffic monitoring, an automated response mechanism, and alert visualization.

> Task 4 — Cyber Security Internship, CodeAlpha

## 📌 Project Overview

This project sets up a fully functional NIDS on an Ubuntu VM that:
- Monitors live network traffic on a bridged network interface
- Detects suspicious activity (ICMP probes, port scans) using custom Suricata rules
- Logs alerts in real time
- Automatically blocks offending IPs via `iptables`
- Visualizes alert data by signature type

## 🛠 Tech Stack

- **Suricata 6.0.4** — open-source IDS/IPS engine
- **Ubuntu 22.04** (VirtualBox VM, Bridged Adapter)
- **iptables** — automated response / blocking
- **Bash** — response automation script
- **Nmap** — attack simulation for testing

## ⚙️ Setup & Configuration

### 1. Installation
```bash
apt update && apt install suricata -y
suricata-update   # pulls Emerging Threats Open ruleset (~68,500 rules)
```

### 2. Network Configuration
- Interface: `enp0s3` (VirtualBox Bridged Adapter, so the VM shares the host's LAN)
- `HOME_NET` set to cover the local subnet in `/etc/suricata/suricata.yaml`
- Config validated with:
```bash
suricata -T -c /etc/suricata/suricata.yaml -i enp0s3
```

### 3. Custom Detection Rules
Defined in `/var/lib/suricata/rules/local.rules`:

```
alert icmp any any -> $HOME_NET any (msg:"ICMP Ping Detected"; sid:1000001; rev:1;)
alert tcp any any -> $HOME_NET any (msg:"Possible Nmap SYN Scan"; flags:S; threshold:type both, track by_src, count 5, seconds 10; sid:1000002; rev:1;)
```

- **Rule 1** detects any ICMP echo request (ping sweep reconnaissance)
- **Rule 2** detects port-scan behavior — 5+ SYN packets from the same source within 10 seconds

### 4. Live Monitoring
```bash
suricata -c /etc/suricata/suricata.yaml -i enp0s3
tail -f /var/log/suricata/fast.log
```
Suricata runs continuously in the foreground, logging matched alerts to `fast.log` and structured JSON events to `eve.json`.

### 5. Automated Response Mechanism
`auto_block.sh` tails the alert log in real time, extracts the source IP of any Nmap-scan alert, and blocks it automatically:

```bash
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
```
This closes the loop from **detection → alert → automated mitigation**, without manual intervention.

## 🧪 Testing / Attack Simulation

Simulated from a separate host on the same bridged network:

```bash
ping <VM_IP>              # triggers ICMP rule
nmap -sT -Pn <VM_IP>      # triggers port-scan rule (1000 ports scanned)
```

**Results:**
- ICMP alerts fired correctly on ping
- Port-scan rule fired multiple times during the Nmap scan
- Source IP was automatically added to `iptables DROP` within seconds, confirmed in `blocked_ips.log`

## 📊 Visualization

Alert counts by signature type, generated from parsed Suricata log data:

| Alert Type | Count |
|---|---|
| Possible Nmap SYN Scan | 5 |
| ICMP Ping Detected | 2 |
| Stream Excessive Retransmissions (side effect of blocked scan) | 1 |

*(see `screenshots/alerts_chart.png`)*

## 📁 Repository Structure

```
CodeAlpha_NetworkIntrusionDetectionSystem/
├── README.md
├── rules/
│   └── local.rules
├── scripts/
│   └── auto_block.sh
└── screenshots/
    ├── config_validation.png
    ├── live_alerts.png
    ├── blocked_ips_log.png
    └── alerts_chart.png
```

## 🎓 Key Learnings

- Configuring and tuning a production-grade IDS engine (Suricata) from scratch
- Writing custom Suricata rules for reconnaissance and scanning behavior
- Bridging VM networking to enable realistic external traffic testing
- Building an automated detection-to-response pipeline using shell scripting and `iptables`
- Parsing and visualizing security log data

## ⚠️ Disclaimer

This project was built in an isolated lab/VM environment for educational purposes as part of the CodeAlpha Cyber Security Internship. Do not run scanning tools or auto-block scripts against networks or systems you do not own or have explicit permission to test.

---
**Author:** Sharanya
**Internship:** CodeAlpha Cyber Security Internship (M1)
