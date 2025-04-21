#!/bin/bash -e

# Se déplacer dans le répertoire contenant les fichiers PEM
cd /root/ipsec/pems

# Copier les fichiers nécessaires dans les répertoires StrongSwan
cp caCert.pem /etc/swanctl/x509ca/
cp remoteKey.pem /etc/swanctl/private/
cp remoteCert.pem /etc/swanctl/x509/
cp /root/ipsec/conf/swanctl.conf /etc/swanctl/conf.d/

# Redémarrer le daemon charon
pkill charon || true
/usr/lib/ipsec/charon &
sleep 1

# Charger les credentials et les connexions
swanctl --load-creds
swanctl --load-conns
