#!/usr/bin/env bash
set -euo pipefail

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonctions pour les messages
print_message() {
    echo -e "${GREEN}[GitLab Setup]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[GitLab Setup][WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[GitLab Setup][ERROR]${NC} $1"
    exit 1
}

GITLAB_NAMESPACE="gitlab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="$(dirname "$SCRIPT_DIR")/confs"

# 1. Vérifier si Helm est disponible
if ! command -v helm &> /dev/null; then
    print_error "Helm n'est pas trouvé. Assurez-vous qu'il est installé et dans le PATH."
fi

# 2. Vérifier si k3d est disponible
if ! command -v k3d &> /dev/null; then
    print_error "k3d n'est pas trouvé. Assurez-vous qu'il est installé et dans le PATH."
fi

# 3. Vérifier si le cluster k3d existe et est en cours d'exécution
print_message "Vérification du cluster k3d..."
if ! k3d cluster list | grep -q "inception-cluster"; then
    print_error "Le cluster k3d 'inception-cluster' n'est pas en cours d'exécution.\n\
    Veuillez d'abord exécuter 'make setup' dans le dossier p3 pour démarrer le cluster."
fi

# 4. Vérifier la connectivité au cluster Kubernetes
print_message "Vérification de la connectivité au cluster Kubernetes..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    print_error "Impossible de se connecter au cluster Kubernetes.\n\
    Assurez-vous que :\n\
    1. Le cluster k3d est en cours d'exécution (make setup dans le dossier p3)\n\
    2. Vous avez exécuté 'make setup' dans le dossier p3 avant d'installer GitLab\n\
    3. Le fichier ~/.kube/config existe et est correctement configuré"
fi

print_message "Connectivité au cluster confirmée."

# 5. Créer le namespace pour GitLab
print_message "Création du namespace '${GITLAB_NAMESPACE}'..."
if ! kubectl create namespace "${GITLAB_NAMESPACE}" 2>/dev/null; then
    print_message "Le namespace '${GITLAB_NAMESPACE}' existe déjà."
fi

# 6. Ajouter le repo Helm de GitLab
print_message "Ajout du repo Helm de GitLab..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# 7. Installer GitLab
print_message "Installation de GitLab (cela peut prendre plusieurs minutes)..."
helm upgrade --install gitlab gitlab/gitlab \
  --namespace "${GITLAB_NAMESPACE}" \
  --values "${CONF_DIR}/gitlab-values.yaml" \
  --timeout 600s

# 8. Attendre que les pods soient prêts
print_message "Attente que les pods GitLab soient prêts..."
kubectl wait --for=condition=available deployment/gitlab-webservice-default -n "${GITLAB_NAMESPACE}" --timeout=600s

# 9. Obtenir le mot de passe root
print_message "Récupération du mot de passe root..."
kubectl get secret gitlab-gitlab-initial-root-password -n "${GITLAB_NAMESPACE}" -o jsonpath='{.data.password}' | base64 --decode ; echo

# 10. Configurer le port-forwarding
print_message "Configuration du port-forwarding pour GitLab..."
kubectl port-forward -n "${GITLAB_NAMESPACE}" svc/gitlab-webservice-default 8080:8181 &

print_message "✅ Installation de GitLab terminée."
print_message "Vous pouvez accéder à GitLab sur http://localhost:8080"
print_message "Utilisez 'root' comme nom d'utilisateur et le mot de passe affiché ci-dessus." 