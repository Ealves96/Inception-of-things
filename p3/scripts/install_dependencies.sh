#!/bin/bash

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Fonctions pour les messages
print_message() {
    echo -e "${GREEN}[DEPS]${NC} $1"
}

print_error() {
    echo -e "${RED}[DEPS][ERROR]${NC} $1"
}

# Set up local bin directory. LOCALBIN est soit passé par le Makefile, soit $HOME/.local/bin par défaut.
LOCALBIN="${LOCALBIN:-$HOME/.local/bin}"
mkdir -p "$LOCALBIN"
print_message "Les binaires seront installés dans: ${LOCALBIN}"

# S'assurer que LOCALBIN est dans le PATH pour ce script et les suivants qu'il pourrait appeler
# Bien que le Makefile le fasse pour setup.sh, c'est bien de l'avoir ici aussi pour la robustesse
# et si ce script est exécuté seul.
export PATH="${LOCALBIN}:${PATH}"

# --- Installation de K3d ---
if ! command -v k3d &> /dev/null || [ ! -f "${LOCALBIN}/k3d" ]; then
    K3D_VERSION="v5.6.0" 
    print_message "Installation de K3d version ${K3D_VERSION}..."
    if curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | \
        TAG="${K3D_VERSION}" K3D_INSTALL_DIR="${LOCALBIN}" USE_SUDO="false" bash; then
        print_message "K3d ${K3D_VERSION} installé avec succès dans ${LOCALBIN}/k3d"
    else
        print_error "L'installation de K3d a échoué."
        exit 1
    fi
else
    print_message "K3d est déjà installé."
fi

# --- Installation de kubectl ---
if ! command -v kubectl &> /dev/null || [ ! -f "${LOCALBIN}/kubectl" ]; then
    print_message "Installation de kubectl..."
    KUBECTL_LATEST=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    if curl -LO "https://dl.k8s.io/release/${KUBECTL_LATEST}/bin/linux/amd64/kubectl"; then
        chmod +x kubectl
        if mv kubectl "${LOCALBIN}/kubectl"; then
            print_message "kubectl installé avec succès dans ${LOCALBIN}/kubectl"
        else
            print_error "Impossible de déplacer kubectl vers ${LOCALBIN}. Vérifiez les permissions."
            rm -f kubectl # Nettoyage
            exit 1
        fi
    else
        print_error "Téléchargement de kubectl échoué."
        exit 1
    fi
else
    print_message "kubectl est déjà installé."
fi

# --- Installation de Helm ---
if ! command -v helm &> /dev/null || [ ! -f "${LOCALBIN}/helm" ]; then
    print_message "Installation de Helm..."
    HELM_VERSION="v3.12.0" # Ou récupérez la dernière version dynamiquement
    HELM_TEMP_DIR=$(mktemp -d)
    if curl -fsSL -o "${HELM_TEMP_DIR}/helm.tar.gz" "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"; then
        tar -zxvf "${HELM_TEMP_DIR}/helm.tar.gz" -C "${HELM_TEMP_DIR}" linux-amd64/helm
        if mv "${HELM_TEMP_DIR}/linux-amd64/helm" "${LOCALBIN}/helm"; then
            chmod +x "${LOCALBIN}/helm"
            print_message "Helm installé avec succès dans ${LOCALBIN}/helm"
        else
            print_error "Impossible de déplacer helm vers ${LOCALBIN}. Vérifiez les permissions."
            rm -rf "$HELM_TEMP_DIR" # Nettoyage
            exit 1
        fi
        rm -rf "$HELM_TEMP_DIR"
    else
        print_error "Téléchargement de Helm échoué."
        rm -rf "$HELM_TEMP_DIR" # Nettoyage
        exit 1
    fi
else
    print_message "Helm est déjà installé."
fi

# --- Installation d'Argo CD CLI ---
if ! command -v argocd &> /dev/null || [ ! -f "${LOCALBIN}/argocd" ]; then
    print_message "Installation de Argo CD CLI..."
    # Récupérer la dernière version depuis GitHub API
    ARGOCD_LATEST_TAG=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$ARGOCD_LATEST_TAG" ]; then
        print_error "Impossible de récupérer la dernière version d'Argo CD CLI. Utilisation d'une version par défaut (ex: v2.9.3)."
        ARGOCD_LATEST_TAG="v2.9.3" # Mettez une version fallback ici ou sortez en erreur
    fi
    print_message "Téléchargement d'Argo CD CLI version ${ARGOCD_LATEST_TAG}..."
    if curl -sSL -o "${LOCALBIN}/argocd" "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_LATEST_TAG}/argocd-linux-amd64"; then
        chmod +x "${LOCALBIN}/argocd"
        print_message "Argo CD CLI installé avec succès dans ${LOCALBIN}/argocd"
    else
        print_error "Téléchargement d'Argo CD CLI échoué."
        # rm -f "${LOCALBIN}/argocd" # Optionnel: supprimer le fichier potentiellement corrompu
        exit 1
    fi
else
    print_message "Argo CD CLI est déjà installé."
fi

# --- Vérification finale des installations ---
print_message "Vérification des installations (PATH: $PATH)..."
ALL_GOOD=true
for cmd_name in k3d kubectl helm argocd; do
    if command -v "$cmd_name" &> /dev/null; then
        # Utiliser --short pour kubectl version client pour éviter des erreurs si pas de serveur
        VERSION_INFO=$($cmd_name version --client --short 2>/dev/null || $cmd_name version 2>&1 | head -n 1)
        print_message "✅ $cmd_name est installé: $($cmd_name --version 2>/dev/null || $cmd_name version --client --short 2>/dev/null || $cmd_name version 2>&1 | head -n 1)"
    else
        print_error "❌ $cmd_name n'est PAS installé ou n'est pas trouvable dans le PATH."
        if [ -f "${LOCALBIN}/${cmd_name}" ]; then
            print_error "   Le fichier ${LOCALBIN}/${cmd_name} existe mais n'est pas dans le PATH ou n'est pas exécutable."
        fi
        ALL_GOOD=false
    fi
done

if [ "$ALL_GOOD" = "false" ]; then
    print_error "Certaines dépendances n'ont pas pu être installées ou vérifiées correctement."
    exit 1
fi

print_message "Installation des dépendances terminée avec succès!"