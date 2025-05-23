#!/bin/bash

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    print_error "Ce script doit être exécuté en tant que root (sudo)"
    exit 1
fi

# Mise à jour du système
print_message "Mise à jour du système..."
apt-get update && apt-get upgrade -y

# Installation des prérequis
print_message "Installation des prérequis..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Installation de Docker
print_message "Installation de Docker..."
if ! command -v docker &> /dev/null; then
    # Ajouter la clé GPG de Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Ajouter le dépôt Docker
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Installer Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Démarrer et activer Docker
    systemctl start docker
    systemctl enable docker
else
    print_message "Docker est déjà installé"
fi

# Installation de Helm
print_message "Installation de Helm..."
if ! command -v helm &> /dev/null; then
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    apt-get update
    apt-get install -y helm
else
    print_message "Helm est déjà installé"
fi

# Installation de K3d
print_message "Installation de K3d..."
if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    print_message "K3d est déjà installé"
fi

# Installation de kubectl
print_message "Installation de kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
else
    print_message "kubectl est déjà installé"
fi

# Installation de Argo CD CLI
print_message "Installation de Argo CD CLI..."
if ! command -v argocd &> /dev/null; then
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
else
    print_message "Argo CD CLI est déjà installé"
fi

# Vérification des installations
print_message "Vérification des installations..."
echo "Docker version:"
docker --version
echo "Helm version:"
helm version
echo "K3d version:"
k3d version
echo "Kubectl version:"
kubectl version --client
echo "Argo CD version:"
argocd version --client

print_message "Installation terminée avec succès!" 