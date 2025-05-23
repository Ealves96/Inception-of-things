.PHONY: setup clean status

# Configuration de K3D et ArgoCD
setup:
	@echo "🚀 Configuration de K3D et ArgoCD..."
	@cd scripts && sudo ./setup.sh

# Nettoyage de l'installation
clean:
	@echo "🧹 Nettoyage de l'installation..."
	@sudo k3d cluster delete argocd-cluster || true
	@sudo kubectl delete namespace argocd || true

# État de l'installation
status:
	@echo "📊 État de l'installation..."
	@k3d cluster list
	@kubectl get pods -n argocd

# Aide
help:
	@echo "Commandes disponibles :"
	@echo "  make setup   - Configure K3D et ArgoCD"
	@echo "  make clean   - Nettoie l'installation"
	@echo "  make status  - Affiche l'état de l'installation"
	@echo "  make help    - Affiche cette aide"