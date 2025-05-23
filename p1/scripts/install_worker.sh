#!/usr/bin/env bash
set -euo pipefail # Mode strict pour les erreurs

# Variables
SERVER_IP="192.168.56.110" # IP du serveur K3s
WORKER_IP="192.168.56.111" # IP de ce worker
K3S_VERSION="v1.27.12+k3s1" # Doit correspondre à la version du serveur pour éviter les problèmes

echo ">>> [WORKER] Mise à jour des paquets et installation des dépendances..."
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y curl net-tools vim git > /dev/null

echo ">>> [WORKER] Attente du token de nœud du serveur (fichier /vagrant/node-token)..."
timeout=120 # 2 minutes
while [ ! -f /vagrant/node-token ]; do
  sleep 5
  timeout=$((timeout-5))
  if [ $timeout -le 0 ]; then
    echo "ERREUR: Le fichier token du serveur (/vagrant/node-token) n'a pas été trouvé à temps."
    exit 1
  fi
  echo "    (Encore en attente du token...)"
done
echo ">>> [WORKER] Token trouvé."

K3S_NODE_TOKEN=$(cat /vagrant/node-token)
if [ -z "${K3S_NODE_TOKEN}" ]; then
  echo "ERREUR: Le token lu est vide."
  exit 1
fi

echo ">>> [WORKER] Installation de K3s en mode agent..."
# K3S_URL : URL du serveur K3s auquel se connecter.
# K3S_TOKEN : Token d'enregistrement.
# --node-ip : Adresse IP que ce nœud (worker) annonce.
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_VERSION}" \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${K3S_NODE_TOKEN}" \
  INSTALL_K3S_EXEC="agent \
    --node-ip ${WORKER_IP}" sh -

echo ">>> [WORKER] Attente de la disponibilité du service K3s Agent..."
timeout=180 # L'agent peut prendre un peu plus de temps
while ! systemctl is-active --quiet k3s-agent; do
  sleep 2
  timeout=$((timeout-2))
  if [ $timeout -le 0 ]; then
    echo "ERREUR: Le service K3s Agent n'a pas démarré à temps."
    journalctl -u k3s-agent --no-pager | tail -n 50
    exit 1
  fi
done
echo ">>> [WORKER] Service K3s Agent actif."

echo ">>> [WORKER] Provisionnement terminé."