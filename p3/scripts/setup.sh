#!/bin/bash

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    print_error "Ce script doit être exécuté en tant que root (sudo)"
    exit 1
fi

# Vérifier si les scripts existent
if [ ! -f "install_dependencies.sh" ] || [ ! -f "setup_k3d.sh" ] || [ ! -f "setup_argocd.sh" ]; then
    print_error "Les scripts nécessaires ne sont pas trouvés dans le répertoire courant"
    print_error "Assurez-vous d'être dans le répertoire p3/scripts"
    exit 1
fi

# Rendre les scripts exécutables
chmod +x install_dependencies.sh
chmod +x setup_k3d.sh
chmod +x setup_argocd.sh

# Étape 1: Installation des dépendances
print_message "Étape 1: Installation des dépendances..."
./install_dependencies.sh
if [ $? -ne 0 ]; then
    print_error "L'installation des dépendances a échoué"
    exit 1
fi

# Étape 2: Configuration de K3d
print_message "Étape 2: Configuration de K3d..."
./setup_k3d.sh
if [ $? -ne 0 ]; then
    print_error "La configuration de K3d a échoué"
    exit 1
fi

# Étape 3: Configuration d'Argo CD
print_message "Étape 3: Configuration d'Argo CD..."
./setup_argocd.sh
if [ $? -ne 0 ]; then
    print_error "La configuration d'Argo CD a échoué"
    exit 1
fi

print_message "Installation terminée avec succès!"
print_message "Pour vérifier que tout fonctionne correctement, exécutez :"
echo "kubectl get pods -n argocd"
echo "kubectl get pods -n dev"
print_message "Pour accéder à l'interface Argo CD :"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443" 