#!/bin/bash -e

# Vérifiez et créez le périphérique TUN si nécessaire
if [ ! -d "/dev/net" ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    chmod 0666 /dev/net/tun
fi

openvpn --config /root/openvpn/conf/client.ovpn