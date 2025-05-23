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

# Nom du cluster
CLUSTER_NAME="inception-cluster"

# Vérifier si le cluster existe déjà
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    print_message "Le cluster $CLUSTER_NAME existe déjà. Suppression..."
    k3d cluster delete "$CLUSTER_NAME"
fi

# Créer le cluster K3d
print_message "Création du cluster K3d..."
k3d cluster create "$CLUSTER_NAME" \
    --api-port 6550 \
    --servers 1 \
    --agents 2 \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer \
    --port 8888:8888@loadbalancer \
    --k3s-arg '--disable=traefik@server:0' \
    --k3s-arg '--disable=servicelb@server:0'

# Attendre que le cluster soit prêt
print_message "Attente que le cluster soit prêt..."
sleep 10

# Vérifier que le cluster est en état "Ready"
if ! kubectl get nodes | grep -q "Ready"; then
    print_error "Le cluster n'est pas prêt"
    exit 1
fi

# Créer les namespaces
print_message "Création des namespaces..."
kubectl create namespace argocd
kubectl create namespace dev

# Vérifier que les namespaces sont créés
if ! kubectl get namespace | grep -q "argocd" || ! kubectl get namespace | grep -q "dev"; then
    print_error "Erreur lors de la création des namespaces"
    exit 1
fi

print_message "Configuration du cluster terminée avec succès!"
print_message "Pour utiliser le cluster, exécutez :"
echo "export KUBECONFIG=$(k3d kubeconfig write $CLUSTER_NAME)" 