#!/bin/sh
# Example iptables rules for segmentation demonstration.
# WARNING: Running this on your host will modify its firewall. Test in a disposable environment.
echo "[iptables] applying sample iptables rules (demo)"
# flush user rules
iptables -F
iptables -t nat -F
iptables -t mangle -F

# drop from OT to IT by default (example subnets)
iptables -A FORWARD -s 192.168.100.0/24 -d 192.168.200.0/24 -j DROP || true

# allow established/related
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# allow docker bridge traffic (be careful: this is permissive)
iptables -A INPUT -i docker0 -j ACCEPT

echo "[iptables] done"
exit 0
