#!/usr/bin/env bash
set -euo pipefail # Mode strict pour les erreurs

# Variables (plus facile à modifier si besoin)
SERVER_IP="192.168.56.110"
K3S_VERSION="v1.27.12+k3s1" # Spécifier une version K3s pour la reproductibilité (optionnel, sinon prend la dernière)

echo ">>> [SERVER] Mise à jour des paquets et installation des dépendances..."
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y curl net-tools vim git > /dev/null # net-tools pour ifconfig si besoin, vim/git pour la commodité

echo ">>> [SERVER] Installation de K3s en mode serveur (controller)..."
# --tls-san : Ajoute l'IP du serveur au certificat TLS de l'API K3s pour une connexion sécurisée.
# --write-kubeconfig-mode 644 : Rend le fichier kubeconfig lisible par l'utilisateur vagrant.
# --node-ip : Adresse IP que ce nœud annonce aux autres.
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_VERSION}" \
  INSTALL_K3S_EXEC="server \
    --tls-san ${SERVER_IP} \
    --tls-san 127.0.0.1 \
    --node-ip ${SERVER_IP} \
    --write-kubeconfig-mode 644" sh -

echo ">>> [SERVER] Attente de la disponibilité du service K3s..."
timeout=120 # 2 minutes
while ! systemctl is-active --quiet k3s; do
  sleep 2
  timeout=$((timeout-2))
  if [ $timeout -le 0 ]; then
    echo "ERREUR: Le service K3s n'a pas démarré à temps."
    journalctl -u k3s --no-pager | tail -n 50
    exit 1
  fi
done
echo ">>> [SERVER] Service K3s actif."

echo ">>> [SERVER] Configuration de kubectl pour l'utilisateur vagrant..."
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
# S'assurer que le kubeconfig pointe vers l'IP publique du serveur, pas 127.0.0.1
sed -i "s|server: https://127.0.0.1:6443|server: https://${SERVER_IP}:6443|g" /home/vagrant/.kube/config
# Vérification que la modification a bien été appliquée
if grep -q "server: https://127.0.0.1:6443" /home/vagrant/.kube/config; then
    echo "ERREUR: La modification du kubeconfig n'a pas fonctionné correctement."
    exit 1
fi
chown -R vagrant:vagrant /home/vagrant/.kube
echo "export KUBECONFIG=/home/vagrant/.kube/config" >> /home/vagrant/.bashrc
echo 'alias k=kubectl' >> /home/vagrant/.bashrc
echo ">>> [SERVER] kubectl configuré. Utilisez 'k get nodes' après connexion SSH."

echo ">>> [SERVER] Copie du token de nœud pour le worker dans /vagrant/node-token..."
# /vagrant est le dossier partagé avec la machine hôte (le répertoire du Vagrantfile)
mkdir -p /vagrant # Au cas où il n'existerait pas encore lors du premier provisionnement
cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token
chown vagrant:vagrant /vagrant/node-token # Pour éviter les problèmes de permission sur l'hôte

# Installation explicite de kubectl si le sujet l'exigeait (K3s fournit k3s kubectl)
# echo ">>> [SERVER] Installation de kubectl (si besoin)..."
# curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# rm kubectl

echo ">>> [SERVER] Provisionnement terminé."