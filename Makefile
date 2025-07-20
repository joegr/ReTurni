# Tournament Service Makefile

# Variables
DOCKER_REGISTRY ?= tournament-service
VERSION ?= latest
NAMESPACE ?= tournament-service

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help build build-all test test-all deploy deploy-k8s clean docker-build docker-push

# Default target
help: ## Show this help message
	@echo "$(BLUE)Tournament Service - Available Commands:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# Development Commands
build: ## Build all services
	@echo "$(BLUE)Building all services...$(NC)"
	@docker-compose build

build-service: ## Build a specific service (usage: make build-service SERVICE=service-name)
	@echo "$(BLUE)Building $(SERVICE)...$(NC)"
	@docker-compose build $(SERVICE)

up: ## Start all services with docker-compose
	@echo "$(BLUE)Starting tournament service...$(NC)"
	@docker-compose up -d

down: ## Stop all services
	@echo "$(BLUE)Stopping tournament service...$(NC)"
	@docker-compose down

logs: ## Show logs for all services
	@docker-compose logs -f

logs-service: ## Show logs for a specific service (usage: make logs-service SERVICE=service-name)
	@docker-compose logs -f $(SERVICE)

# Testing Commands
test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@docker-compose exec tournament-api python -m pytest
	@docker-compose exec elo-service python -m pytest
	@docker-compose exec leaderboard-svc python -m pytest
	@docker-compose exec review-workflow python -m pytest
	@docker-compose exec hash-verification python -m pytest
	@docker-compose exec notification-svc python -m pytest
	@docker-compose exec team-management python -m pytest
	@docker-compose exec match-scheduling python -m pytest
	@docker-compose exec audit-service python -m pytest

test-service: ## Run tests for a specific service (usage: make test-service SERVICE=service-name)
	@echo "$(BLUE)Running tests for $(SERVICE)...$(NC)"
	@docker-compose exec $(SERVICE) python -m pytest

# Docker Commands
docker-build: ## Build all Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	@docker build -t $(DOCKER_REGISTRY)/tournament-api:$(VERSION) ./services/tournament-api
	@docker build -t $(DOCKER_REGISTRY)/elo-service:$(VERSION) ./services/elo-service
	@docker build -t $(DOCKER_REGISTRY)/leaderboard-svc:$(VERSION) ./services/leaderboard-svc
	@docker build -t $(DOCKER_REGISTRY)/review-workflow:$(VERSION) ./services/review-workflow
	@docker build -t $(DOCKER_REGISTRY)/hash-verification:$(VERSION) ./services/hash-verification
	@docker build -t $(DOCKER_REGISTRY)/notification-svc:$(VERSION) ./services/notification-svc
	@docker build -t $(DOCKER_REGISTRY)/team-management:$(VERSION) ./services/team-management
	@docker build -t $(DOCKER_REGISTRY)/match-scheduling:$(VERSION) ./services/match-scheduling
	@docker build -t $(DOCKER_REGISTRY)/audit-service:$(VERSION) ./services/audit-service
	@docker build -t $(DOCKER_REGISTRY)/admin-dashboard:$(VERSION) ./frontend/admin-dashboard

docker-push: ## Push all Docker images to registry
	@echo "$(BLUE)Pushing Docker images...$(NC)"
	@docker push $(DOCKER_REGISTRY)/tournament-api:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/elo-service:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/leaderboard-svc:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/review-workflow:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/hash-verification:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/notification-svc:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/team-management:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/match-scheduling:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/audit-service:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/admin-dashboard:$(VERSION)

# Kubernetes Commands
deploy-k8s: ## Deploy to Kubernetes
	@echo "$(BLUE)Deploying to Kubernetes...$(NC)"
	@kubectl apply -f k8s/namespace.yaml
	@kubectl apply -f k8s/secrets.yaml
	@kubectl apply -f k8s/configmaps.yaml
	@kubectl apply -f k8s/storage.yaml
	@kubectl apply -f k8s/databases.yaml
	@kubectl apply -f k8s/services.yaml
	@kubectl apply -f k8s/deployments.yaml
	@kubectl apply -f k8s/hpa.yaml
	@kubectl apply -f k8s/ingress.yaml
	@echo "$(GREEN)Deployment complete!$(NC)"

deploy-k8s-service: ## Deploy a specific service to Kubernetes (usage: make deploy-k8s-service SERVICE=service-name)
	@echo "$(BLUE)Deploying $(SERVICE) to Kubernetes...$(NC)"
	@kubectl apply -f k8s/deployments.yaml
	@kubectl rollout restart deployment/$(SERVICE) -n $(NAMESPACE)

delete-k8s: ## Delete Kubernetes deployment
	@echo "$(YELLOW)Deleting Kubernetes deployment...$(NC)"
	@kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
	@kubectl delete -f k8s/hpa.yaml --ignore-not-found=true
	@kubectl delete -f k8s/deployments.yaml --ignore-not-found=true
	@kubectl delete -f k8s/services.yaml --ignore-not-found=true
	@kubectl delete -f k8s/databases.yaml --ignore-not-found=true
	@kubectl delete -f k8s/storage.yaml --ignore-not-found=true
	@kubectl delete -f k8s/configmaps.yaml --ignore-not-found=true
	@kubectl delete -f k8s/secrets.yaml --ignore-not-found=true
	@kubectl delete -f k8s/namespace.yaml --ignore-not-found=true

# Database Commands
db-migrate: ## Run database migrations
	@echo "$(BLUE)Running database migrations...$(NC)"
	@docker-compose exec tournament-api python manage.py migrate

db-seed: ## Seed database with sample data
	@echo "$(BLUE)Seeding database...$(NC)"
	@docker-compose exec tournament-api python manage.py seed

db-reset: ## Reset database (WARNING: This will delete all data)
	@echo "$(RED)WARNING: This will delete all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose exec tournament-api python manage.py flush --noinput; \
		echo "$(GREEN)Database reset complete!$(NC)"; \
	else \
		echo "$(YELLOW)Database reset cancelled.$(NC)"; \
	fi

# Monitoring Commands
monitor: ## Open monitoring dashboards
	@echo "$(BLUE)Opening monitoring dashboards...$(NC)"
	@echo "$(GREEN)Prometheus:$(NC) http://localhost:9090"
	@echo "$(GREEN)Grafana:$(NC) http://localhost:3001 (admin/admin)"
	@echo "$(GREEN)RabbitMQ Management:$(NC) http://localhost:15672 (tournament_user/tournament_password)"

# Health Check Commands
health: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@curl -f http://localhost:8080/health || echo "$(RED)API Gateway: DOWN$(NC)"
	@curl -f http://localhost:8000/health || echo "$(RED)Tournament API: DOWN$(NC)"
	@curl -f http://localhost:8081/health || echo "$(RED)ELO Service: DOWN$(NC)"
	@curl -f http://localhost:8082/health || echo "$(RED)Leaderboard Service: DOWN$(NC)"
	@curl -f http://localhost:8083/health || echo "$(RED)Review Workflow: DOWN$(NC)"
	@curl -f http://localhost:8084/health || echo "$(RED)Hash Verification: DOWN$(NC)"
	@curl -f http://localhost:8085/health || echo "$(RED)Notification Service: DOWN$(NC)"
	@curl -f http://localhost:8086/health || echo "$(RED)Team Management: DOWN$(NC)"
	@curl -f http://localhost:8087/health || echo "$(RED)Match Scheduling: DOWN$(NC)"
	@curl -f http://localhost:8088/health || echo "$(RED)Audit Service: DOWN$(NC)"

# Utility Commands
clean: ## Clean up Docker resources
	@echo "$(BLUE)Cleaning up Docker resources...$(NC)"
	@docker-compose down -v
	@docker system prune -f
	@docker volume prune -f

clean-k8s: ## Clean up Kubernetes resources
	@echo "$(BLUE)Cleaning up Kubernetes resources...$(NC)"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true

# Development Setup
setup: ## Initial setup for development
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@cp .env.example .env
	@echo "$(GREEN)Please update .env with your configuration$(NC)"
	@echo "$(GREEN)Then run: make up$(NC)"

# Production Commands
prod-build: ## Build production images
	@echo "$(BLUE)Building production images...$(NC)"
	@docker build -t $(DOCKER_REGISTRY)/tournament-api:$(VERSION) --target production ./services/tournament-api
	@docker build -t $(DOCKER_REGISTRY)/elo-service:$(VERSION) --target production ./services/elo-service
	@docker build -t $(DOCKER_REGISTRY)/leaderboard-svc:$(VERSION) --target production ./services/leaderboard-svc
	@docker build -t $(DOCKER_REGISTRY)/review-workflow:$(VERSION) --target production ./services/review-workflow
	@docker build -t $(DOCKER_REGISTRY)/hash-verification:$(VERSION) --target production ./services/hash-verification
	@docker build -t $(DOCKER_REGISTRY)/notification-svc:$(VERSION) --target production ./services/notification-svc
	@docker build -t $(DOCKER_REGISTRY)/team-management:$(VERSION) --target production ./services/team-management
	@docker build -t $(DOCKER_REGISTRY)/match-scheduling:$(VERSION) --target production ./services/match-scheduling
	@docker build -t $(DOCKER_REGISTRY)/audit-service:$(VERSION) --target production ./services/audit-service
	@docker build -t $(DOCKER_REGISTRY)/admin-dashboard:$(VERSION) --target production ./frontend/admin-dashboard

prod-deploy: ## Deploy to production
	@echo "$(BLUE)Deploying to production...$(NC)"
	@make prod-build
	@make docker-push
	@make deploy-k8s

# Security Commands
security-scan: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	@docker run --rm -v $(PWD):/app aquasec/trivy fs /app
	@docker run --rm -v $(PWD):/app aquasec/trivy config /app

# Backup Commands
backup: ## Create database backup
	@echo "$(BLUE)Creating database backup...$(NC)"
	@docker-compose exec postgres pg_dump -U tournament_user tournament_db > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore: ## Restore database from backup (usage: make restore BACKUP=backup_file.sql)
	@echo "$(BLUE)Restoring database from $(BACKUP)...$(NC)"
	@docker-compose exec -T postgres psql -U tournament_user tournament_db < $(BACKUP) 