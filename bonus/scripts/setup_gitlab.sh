#!/usr/bin/env bash
set -euo pipefail

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_message() {
  echo -e "${GREEN}[GitLab Setup]${NC} $1"
}
print_error() {
  echo -e "${RED}[GitLab Setup][ERROR]${NC} $1"
  exit 1
}

# 1) Namespace
NAMESPACE="gitlab"
print_message "Création (ou vérif.) du namespace '${NAMESPACE}'…"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# 2) Helm repo
print_message "Ajout / mise à jour du repo Helm 'gitlab'…"
helm repo add gitlab https://charts.gitlab.io || true
helm repo update

# 3) Installation / Upgrade de GitLab
print_message "Installation / upgrade de GitLab via chart 'gitlab/gitlab'…"
helm upgrade --install gitlab gitlab/gitlab \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 15m \
  -f ../confs/gitlab-values.yaml

# 4) Attente des principaux déploiements
for deploy in gitlab-gitlab-webservice-default gitlab-gitlab-pgbouncer-default gitlab-gitlab-sidekiq-default; do
  print_message "Attente du déploiement '${deploy}'…"
  kubectl rollout status deployment/"${deploy}" -n "${NAMESPACE}" --timeout=5m \
    || print_error "Le déploiement ${deploy} n'est pas prêt après 5m"
done

print_message "✅ GitLab est installé et prêt dans le namespace ${NAMESPACE} !"
