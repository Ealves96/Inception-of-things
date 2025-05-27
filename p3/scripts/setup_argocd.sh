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

# Vérifier si kubectl est configuré
if ! kubectl get nodes &> /dev/null; then
    print_error "kubectl n'est pas configuré correctement"
    exit 1
fi

# Ajouter le repo Helm d'Argo
print_message "Ajout du repo Helm d'Argo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Installer Argo CD CRDs
print_message "Installation des CRDs d'Argo CD..."
kubectl apply -f ../manifests/argocd-crds.yaml

# Installer Argo CD
print_message "Installation d'Argo CD..."
kubectl apply -f ../manifests/argocd-install.yaml

# Attendre que Argo CD soit prêt
print_message "Attente qu'Argo CD soit prêt..."
timeout=300
while [ $timeout -gt 0 ]; do
    if kubectl get pods -n argocd | grep -q "Running"; then
        print_message "Argo CD est prêt!"
        break
    fi
    sleep 5
    timeout=$((timeout-5))
    echo "Encore $timeout secondes..."
done

if [ $timeout -le 0 ]; then
    print_error "Argo CD n'a pas démarré à temps"
    exit 1
fi

# Récupérer le mot de passe admin
print_message "Récupération du mot de passe admin..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Configurer l'application
print_message "Configuration de l'application..."
kubectl apply -f ../manifests/application.yaml

print_message "Installation terminée avec succès!"
print_message "Pour accéder à l'interface Argo CD :"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
print_message "Mot de passe admin : $ARGOCD_PASSWORD" 