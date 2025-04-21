#!/bin/bash -e

# Assurez que les permissions sont correctes
chmod 600 /root/wireguard/conf/wg0.conf
# Démarrez WireGuard
wg-quick up wireguard/conf/wg0.conf