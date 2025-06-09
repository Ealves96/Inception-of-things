#!/usr/bin/env bash
set -euo pipefail

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonctions pour les messages
print_message() {
    echo -e "${GREEN}[ArgoCD GitLab Config]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ArgoCD GitLab Config][WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ArgoCD GitLab Config][ERROR]${NC} $1"
    exit 1
}

# 1. Vérifier si ArgoCD CLI est disponible
if ! command -v argocd &> /dev/null; then
    print_error "ArgoCD CLI n'est pas trouvé. Assurez-vous qu'il est installé et dans le PATH."
fi

# 2. Vérifier si le namespace argocd existe
if ! kubectl get namespace argocd &> /dev/null; then
    print_error "Le namespace 'argocd' n'existe pas.\n\
    Assurez-vous que ArgoCD est correctement installé dans le dossier p3."
fi

# 3. Attendre que GitLab soit prêt
print_message "Attente que GitLab soit prêt..."
if ! kubectl wait --for=condition=available deployment/gitlab-webservice-default -n gitlab --timeout=300s; then
    print_error "GitLab n'est pas prêt après 5 minutes d'attente.\n\
    Vérifiez l'état des pods avec : kubectl get pods -n gitlab"
fi

# 4. Configurer le port-forwarding pour GitLab
print_message "Configuration du port-forwarding pour GitLab..."
kubectl port-forward -n gitlab svc/gitlab-webservice-default 8080:8181 &
GITLAB_PID=$!

# 5. Attendre que GitLab soit accessible
print_message "Attente que GitLab soit accessible..."
until curl -s http://localhost:8080 > /dev/null; do
    sleep 5
    echo -n "."
done
echo

# 6. Configurer le port-forwarding pour ArgoCD
print_message "Configuration du port-forwarding pour ArgoCD..."
kubectl port-forward -n argocd svc/argocd-server 8081:443 &
ARGOCD_PID=$!

# 7. Attendre que ArgoCD soit accessible
print_message "Attente que ArgoCD soit accessible..."
until curl -s -k https://localhost:8081 > /dev/null; do
    sleep 5
    echo -n "."
done
echo

# 8. Se connecter à ArgoCD
print_message "Connexion à ArgoCD..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
if ! argocd login localhost:8081 --username admin --password "$ARGOCD_PASSWORD" --insecure; then
    print_error "Impossible de se connecter à ArgoCD.\n\
    Vérifiez que :\n\
    1. ArgoCD est correctement installé\n\
    2. Le port 8081 n'est pas déjà utilisé\n\
    3. Le mot de passe admin est correct"
fi

# 9. Configurer GitLab comme repo dans ArgoCD
print_message "Configuration de GitLab comme repo dans ArgoCD..."
if ! argocd repo add http://localhost:8080/root/Inception-of-things.git --username root --password "$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d)" --insecure; then
    print_error "Impossible d'ajouter GitLab comme repo dans ArgoCD.\n\
    Vérifiez que :\n\
    1. GitLab est accessible sur http://localhost:8080\n\
    2. Le projet existe dans GitLab\n\
    3. Les identifiants sont corrects"
fi

# 10. Nettoyer les processus de port-forwarding
kill $GITLAB_PID $ARGOCD_PID

print_message "✅ Configuration d'ArgoCD pour GitLab terminée."
print_message "Vous pouvez maintenant utiliser GitLab comme source pour vos applications ArgoCD." 