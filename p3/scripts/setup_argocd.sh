#!/usr/bin/env bash
set -euo pipefail # S'arrête en cas d'erreur, si une variable non définie est utilisée, ou si une commande dans un pipe échoue

# Couleurs pour les messages (optionnel, mais aide à la lisibilité)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_message() {
    echo -e "${GREEN}[ArgoCD Setup]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ArgoCD Setup][WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ArgoCD Setup][ERROR]${NC} $1"
    exit 1 # Quitte le script en cas d'erreur
}

ARGOCD_NAMESPACE="argocd"
# URL du manifeste d'installation officiel. 'stable' pointe vers la dernière version stable.
# Vous pouvez aussi pointer vers une version spécifique si besoin, par exemple:
# OFFICIAL_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml"
OFFICIAL_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# 1. Vérifier si kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl n'est pas trouvé. Assurez-vous qu'il est installé et dans le PATH."
fi

# 2. Vérifier la connectivité au cluster Kubernetes
print_message "Vérification de la connectivité au cluster Kubernetes..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    print_error "Impossible de se connecter au cluster Kubernetes. Vérifiez la configuration de k3d et kubeconfig."
fi
print_message "Connectivité au cluster confirmée."

# 3. Créer le namespace pour Argo CD s'il n'existe pas
print_message "Vérification de l'existence du namespace '${ARGOCD_NAMESPACE}'..."
if ! kubectl get namespace "${ARGOCD_NAMESPACE}" > /dev/null 2>&1; then
    print_message "Création du namespace '${ARGOCD_NAMESPACE}'..."
    if ! kubectl create namespace "${ARGOCD_NAMESPACE}"; then
        print_error "Échec de la création du namespace '${ARGOCD_NAMESPACE}'."
    fi
    print_message "Namespace '${ARGOCD_NAMESPACE}' créé avec succès."
else
    print_message "Le namespace '${ARGOCD_NAMESPACE}' existe déjà."
fi

# 4. Appliquer le manifeste d'installation officiel d'Argo CD
print_message "Application du manifeste d'installation d'Argo CD depuis ${OFFICIAL_MANIFEST_URL}..."
if ! kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${OFFICIAL_MANIFEST_URL}"; then
    # Tenter une nouvelle fois en cas de problème réseau temporaire (optionnel)
    print_warning "Première tentative d'application échouée. Nouvelle tentative dans 5 secondes..."
    sleep 5
    if ! kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${OFFICIAL_MANIFEST_URL}"; then
        print_error "Échec de l'application du manifeste d'installation d'Argo CD après une nouvelle tentative."
    fi
fi
print_message "Manifeste d'installation d'Argo CD appliqué avec succès."

# 5. Attendre que les déploiements clés d'Argo CD soient prêts
print_message "Attente que les principaux déploiements d'Argo CD soient disponibles..."
# Le manifeste 'stable' peut inclure plusieurs composants. On attend les plus importants.
# Vous pouvez ajouter d'autres déploiements si nécessaire (ex: argocd-repo-server, argocd-dex-server)
KEY_DEPLOYMENTS=("argocd-server" "argocd-repo-server" "argocd-applicationset-controller" "argocd-dex-server" "argocd-redis" "argocd-notifications-controller")
for deploy in "${KEY_DEPLOYMENTS[@]}"; do
    print_message "Attente du déploiement '${deploy}'..."
    if ! kubectl wait --for=condition=available deployment/"${deploy}" -n "${ARGOCD_NAMESPACE}" --timeout=300s; then
        print_error "Le déploiement '${deploy}' n'est pas devenu disponible dans le délai imparti."
        # Afficher les logs du pod en échec peut aider ici
        kubectl logs "deployment/${deploy}" -n "${ARGOCD_NAMESPACE}" --tail=50 || true
    fi
    print_message "Déploiement '${deploy}' est disponible."
done

# 6. (Optionnel mais recommandé pour le débogage) Afficher l'état des pods Argo CD
print_message "État actuel des pods dans le namespace '${ARGOCD_NAMESPACE}':"
kubectl get pods -n "${ARGOCD_NAMESPACE}" -o wide

# 7. Instructions pour l'utilisateur (le port-forward est une étape manuelle généralement)
print_message "✅ Installation de base d'Argo CD terminée."
print_message "Pour accéder à l'interface Argo CD, vous pouvez utiliser le port-forwarding."
print_message "Exécutez dans un autre terminal : kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:443"
print_message "Ensuite, ouvrez https://localhost:8080 dans votre navigateur (acceptez l'avertissement de certificat)."
print_message "Pour obtenir le mot de passe initial (si vous n'avez pas encore changé le secret) :"
print_message "  kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"

# 8) Créer l’Application Argo CD pour déployer votre app
print_message "Création de l’Application Argo CD pour déployer dans dev…"
# kubectl apply -f ../manifests/application.yaml
