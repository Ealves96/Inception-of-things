.PHONY: setup clean status help

# Configuration de GitLab
setup:
	@echo "🚀 Configuration de GitLab..."
	@chmod +x scripts/setup_gitlab.sh
	@chmod +x scripts/configure_argocd_gitlab.sh
	@./scripts/setup_gitlab.sh
	@./scripts/configure_argocd_gitlab.sh

# Nettoyage de l'installation
clean:
	@echo "🧹 Nettoyage de l'installation GitLab..."
	@helm uninstall gitlab -n gitlab || true
	@kubectl delete namespace gitlab || true
	@rm -f confs/gitlab-values.yaml
	@echo "✅ Nettoyage terminé"

# État de l'installation
status:
	@echo "📊 État de l'installation GitLab..."
	@echo "Pods GitLab :"
	@kubectl get pods -n gitlab
	@echo "\nServices GitLab :"
	@kubectl get svc -n gitlab

# Aide
help:
	@echo "Commandes disponibles :"
	@echo "  make setup   - Configure GitLab et l'intègre avec ArgoCD"
	@echo "  make clean   - Nettoie l'installation GitLab"
	@echo "  make status  - Affiche l'état de l'installation GitLab"
	@echo "  make help    - Affiche cette aide" 