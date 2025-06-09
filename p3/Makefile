.PHONY: setup clean status help

# Set up local bin directory
LOCALBIN := $(HOME)/.local/bin
$(shell mkdir -p $(LOCALBIN))
export PATH := $(LOCALBIN):$(PATH)

# Configuration de K3D et ArgoCD
setup:
	@echo "🚀 Configuration de K3D et ArgoCD..."
	@mkdir -p $(HOME)/.kube
	@touch $(HOME)/.kube/config
	@k3d cluster delete inception-cluster 2>/dev/null || true
	@docker system prune -f >/dev/null 2>&1 || true
	@cd scripts && \
	LOCALBIN="$(LOCALBIN)" \
	PATH="$(LOCALBIN):$(PATH)" \
	KUBECONFIG="$(HOME)/.kube/config" \
	./setup.sh

# Nettoyage de l'installation
clean:
	@echo "🧹 Nettoyage de l'installation..."
	@kubectl delete namespace argocd 2>/dev/null || true
	@kubectl delete namespace dev 2>/dev/null || true
	@k3d cluster delete inception-cluster 2>/dev/null || true
	@rm -f $(HOME)/.kube/config
	@docker system prune -f >/dev/null 2>&1 || true
	@docker volume prune -f >/dev/null 2>&1 || true
	@docker network prune -f >/dev/null 2>&1 || true
	@echo "✅ Nettoyage terminé"

# État de l'installation
status:
	@echo "📊 État de l'installation..."
	@echo "Clusters K3D :"
	@k3d cluster list
	@echo "\nPods ArgoCD :"
	@kubectl get pods -n argocd
	@echo "\nPods Dev :"
	@kubectl get pods -n dev

# Aide
help:
	@echo "Commandes disponibles :"
	@echo "  make setup   - Configure K3D et ArgoCD"
	@echo "  make clean   - Nettoie l'installation"
	@echo "  make status  - Affiche l'état de l'installation"
	@echo "  make help	- Affiche cette aide"