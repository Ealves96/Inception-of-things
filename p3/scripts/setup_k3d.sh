#!/usr/bin/env bash
set -euo pipefail

# couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

print() { echo -e "${GREEN}[K3D]${NC} $1"; }
err()   { echo -e "${RED}[K3D]${NC} $1"; exit 1; }

CLUSTER="inception-cluster"

# 2) Créer le cluster (Traefik désactivé, ports exposés, mise à jour kubeconfig)
print "Creating cluster ${CLUSTER}..."
k3d cluster create "${CLUSTER}" \
  --servers 1 \
  --agents 2 \
  --api-port 6550 \
  --port 80:80@loadbalancer \
  --port 443:443@loadbalancer \
  --port 8888:8888@loadbalancer \
  --k3s-arg '--disable=traefik@server:0' \

# 3) Vérifier kubeconfig
print "Kubeconfig written to ~/.kube/config"
export KUBECONFIG="${HOME}/.kube/config"

# 4) Attendre que les nœuds soient Ready
print "Waiting for nodes to be Ready..."
until kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -qE "^Ready"; do
  sleep 5
  echo -n "."
done
echo

print "✅ Cluster ${CLUSTER} is up!"
