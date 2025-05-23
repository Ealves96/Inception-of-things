#!/usr/bin/env bash
set -euo pipefail

# –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Variables
SERVER_IP="192.168.56.110"
K3S_VERSION="v1.27.12+k3s1"  # version fixe (facultatif)

# 1) Mise à jour et dépendances
echo ">>> [SERVER] Mise à jour des paquets et installation des dépendances..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl net-tools vim git

# 2) Installation K3s server
echo ">>> [SERVER] Installation de K3s en mode serveur..."
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_VERSION}" \
  INSTALL_K3S_EXEC="server \
    --bind-address ${SERVER_IP} \
    --advertise-address ${SERVER_IP} \
    --node-ip ${SERVER_IP} \
    --write-kubeconfig-mode 644" sh -

# 3) Attente que k3s soit prêt
echo ">>> [SERVER] Attente de la disponibilité du service k3s..."
timeout=120
until systemctl is-active --quiet k3s; do
  sleep 2
  timeout=$((timeout-2))
  if [ $timeout -le 0 ]; then
    echo "ERREUR: k3s n'a pas démarré à temps." >&2
    journalctl -u k3s --no-pager | tail -n 50
    exit 1
  fi
done
echo ">>> [SERVER] Service k3s actif."

# 4) Vérification de l'écoute API
echo ">>> [SERVER] Vérification que l'API Server écoute sur ${SERVER_IP}:6443"
ss -lntp | grep ":6443"

# 5) Configuration kubectl pour l'utilisateur VAGRANT
echo ">>> [SERVER] Configuration de kubectl pour l'utilisateur vagrant..."
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config
echo "export KUBECONFIG=/home/vagrant/.kube/config" >> /home/vagrant/.bashrc
echo 'alias k=kubectl' >> /home/vagrant/.bashrc

# 6) Vérification finale
echo ">>> [SERVER] Vérification finale..."
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get pods -A

echo ">>> [SERVER] Provisionnement terminé."

sudo sed -i "s|server: https://127.0.0.1:6443|server: https://192.168.56.110:6443|g" /etc/rancher/k3s/k3s.yaml 