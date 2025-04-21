#!/bin/bash -e

# Fonction pour démarrer le VPN
start_vpn() {
  VPN=$1
  echo "*** Démarrage du docker pour $VPN ***"
  RUN="$VPN.sh" docker-compose up -d > /dev/null 2>&1
  sleep 6
}

# Fonction pour démarrer le serveur iperf
run_iperf_server() {
  SERVER_CONTAINER=$1
  echo "    Démarrage du serveur iperf sur $SERVER_CONTAINER"
  docker exec "$SERVER_CONTAINER" iperf -s > /dev/null 2>&1 &
  echo $! # Retourner le PID du serveur
}

# Fonction pour exécuter le client iperf
run_iperf_client() {
  CLIENT_CONTAINER=$1
  SERVER_IP=$2
  echo "    Exécution du client iperf sur $CLIENT_CONTAINER vers le serveur $SERVER_IP"
  docker exec "$CLIENT_CONTAINER" iperf -c "$SERVER_IP" | awk '/local/ || /Interval/ || /sec/ {print $0}'
}

# Fonction pour tester iperf
test_iperf() {
  SERVER_CONTAINER=$1
  CLIENT_CONTAINER=$2
  SERVER_IP=$3
  echo "    Test de iperf de $CLIENT_CONTAINER vers $SERVER_CONTAINER"
  echo "$CLIENT_CONTAINER vers $SERVER_CONTAINER" >> iperf_rapport.txt

  SERVER_PID=$(run_iperf_server "$SERVER_CONTAINER")
  sleep 1
  run_iperf_client "$CLIENT_CONTAINER" "$SERVER_IP" >> iperf_rapport.txt
  kill -9 $SERVER_PID > /dev/null 2>&1
}

# Fonction pour tester un VPN spécifique
test_vpn() {
  VPN=$1
  echo "*** Test de $VPN ***" >> iperf_rapport.txt
  test_iperf FarS MainS 10.0.2.2
  test_iperf FarC1 MainC1 10.0.2.10
  test_iperf FarC2 Remote 10.0.2.11
}

# Fonction de nettoyage
cleanup() {
  echo "*** Nettoyage des dockers ***"
  docker-compose down -t 1 > /dev/null 2>&1
}

# Fonction pour écrire le rapport
write_report() {
  VPN=$1
  echo "*** Ajout du rapport pour $VPN ***"
  echo "=== Fin du rapport pour $VPN ===" >> iperf_rapport.txt
  echo "" >> iperf_rapport.txt
}

# Assurez-vous que le nettoyage est effectué à la fin
trap cleanup EXIT

# Définir les tests à effectuer
TESTS=${1:-openvpn wireguard ipsec}

# Nettoyage initial
cleanup
echo "*** Suppression de l'ancien rapport ***"
rm -f iperf_rapport.txt

# Boucle sur chaque VPN pour démarrer, tester et nettoyer
for VPN in $TESTS; do
  start_vpn "$VPN"
  test_vpn "$VPN"
  write_report "$VPN"
  echo -e "*** Nettoyage du docker pour $VPN ***\n"
  cleanup
done

echo "Terminé!"
