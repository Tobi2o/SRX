#!/bin/bash -e

# Définir le répertoire de travail
cd /etc/swanctl

# Générer les clés privées pour mains, fars et remote
pki --gen --type ed25519 --outform pem > mainsKey.pem
pki --gen --type ed25519 --outform pem > farsKey.pem
pki --gen --type ed25519 --outform pem > remoteKey.pem
echo "Clés privées générées"

# Créer l'autorité de certification (CA) basée sur la clé privée de mains
pki --self --ca --lifetime 3652 --in mainsKey.pem \
           --dn "C=CH, O=heig, CN=heig Root CA" \
           --outform pem > caCert.pem
echo "CA générée"

# Générer les CSR (Certificate Signing Requests) pour mains, fars et remote
pki --req --type priv --in mainsKey.pem \
          --dn "C=CH, O=heig, CN=heig.mains" \
          --san mains --san 10.0.0.2 \
          --outform pem > mainsReq.pem

pki --req --type priv --in farsKey.pem \
          --dn "C=CH, O=heig, CN=heig.fars" \
          --san fars --san 10.0.0.3 \
          --outform pem > farsReq.pem

pki --req --type priv --in remoteKey.pem \
          --dn "C=CH, O=heig, CN=heig.remote" \
          --san remote --san 10.0.0.4 \
          --outform pem > remoteReq.pem
echo "CSR générées"

# Signer les CSR pour mains, fars et remote
pki --issue --cacert caCert.pem --cakey mainsKey.pem \
            --type pkcs10 --in mainsReq.pem --serial 01 --lifetime 1826 \
            --outform pem > mainsCert.pem

pki --issue --cacert caCert.pem --cakey mainsKey.pem \
            --type pkcs10 --in farsReq.pem --serial 02 --lifetime 1826 \
            --outform pem > farsCert.pem

pki --issue --cacert caCert.pem --cakey mainsKey.pem \
            --type pkcs10 --in remoteReq.pem --serial 03 --lifetime 1826 \
            --outform pem > remoteCert.pem
echo "CSR signées et certificats émis"

# Copier tous les fichiers PEM dans le répertoire /root
cp *.pem /root
echo "Fichiers PEM copiés dans /root"

# Supprimer les fichiers PEM du répertoire actuel
rm *.pem
echo "Anciennes copies des fichiers PEM supprimées"
