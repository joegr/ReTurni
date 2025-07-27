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

.PHONY: help build up down restart logs test clean format lint security-scan backup migrate

# Default target
help: ## Show this help message
	@echo "Tournament Management System - Local Development"
	@echo "================================================="
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Environment setup
setup: ## Set up the development environment
	@echo "Setting up development environment..."
	@mkdir -p logs data/postgres data/redis data/rabbitmq
	@chmod 755 scripts/init-db.sql
	@echo "Environment setup complete"

# Docker operations
build: ## Build all Docker images
	@echo "Building Docker images..."
	docker-compose build --parallel

up: setup ## Start all services
	@echo "Starting tournament management system..."
	docker-compose up -d
	@echo "Services are starting up. Check status with 'make status'"
	@echo "API Gateway will be available at: http://localhost:8080"
	@echo "Grafana dashboard will be available at: http://localhost:3001"
	@echo "RabbitMQ management will be available at: http://localhost:15672"

down: ## Stop all services
	@echo "Stopping all services..."
	docker-compose down

restart: down up ## Restart all services

status: ## Show status of all services
	@echo "Service Status:"
	@echo "=============="
	docker-compose ps

logs: ## Show logs for all services
	docker-compose logs -f

logs-service: ## Show logs for a specific service (usage: make logs-service SERVICE=api-gateway)
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make logs-service SERVICE=<service-name>"; \
		echo "Available services: api-gateway, tournament-api, elo-service, leaderboard-service, etc."; \
	else \
		docker-compose logs -f $(SERVICE); \
	fi

# Database operations
db-reset: ## Reset the database (WARNING: This will delete all data!)
	@echo "Resetting database..."
	docker-compose stop postgres
	docker-compose rm -f postgres
	docker volume rm returni_postgres_data 2>/dev/null || true
	docker-compose up -d postgres
	@echo "Database reset complete. Waiting for initialization..."
	sleep 10

db-backup: ## Create a database backup
	@echo "Creating database backup..."
	@mkdir -p backups
	docker-compose exec postgres pg_dump -U tournament_user tournament_db > backups/tournament_db_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Backup created in backups/ directory"

db-restore: ## Restore database from backup (usage: make db-restore BACKUP=filename.sql)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Usage: make db-restore BACKUP=<backup-filename>"; \
		echo "Available backups:"; \
		ls -la backups/*.sql 2>/dev/null || echo "No backups found"; \
	else \
		echo "Restoring database from $(BACKUP)..."; \
		docker-compose exec -T postgres psql -U tournament_user -d tournament_db < backups/$(BACKUP); \
		echo "Database restore complete"; \
	fi

migrate: ## Run database migrations
	@echo "Running database migrations..."
	docker-compose exec tournament-api alembic upgrade head
	@echo "Migrations complete"

# Testing
test: ## Run all tests
	@echo "Running all tests..."
	docker-compose exec api-gateway python -m pytest tests/ -v
	docker-compose exec tournament-api python -m pytest tests/ -v
	docker-compose exec elo-service python -m pytest tests/ -v
	docker-compose exec leaderboard-service python -m pytest tests/ -v
	@echo "All tests complete"

test-api: ## Run API tests only
	@echo "Running API tests..."
	docker-compose exec api-gateway python -m pytest tests/ -v --tb=short

test-elo: ## Run ELO service tests
	@echo "Running ELO service tests..."
	docker-compose exec elo-service python -m pytest tests/ -v

test-leaderboard: ## Run leaderboard service tests
	@echo "Running leaderboard service tests..."
	docker-compose exec leaderboard-service python -m pytest tests/ -v

test-integration: ## Run integration tests
	@echo "Running integration tests..."
	@echo "Starting test environment..."
	docker-compose -f docker-compose.test.yml up -d
	sleep 30
	docker-compose -f docker-compose.test.yml exec test-runner python -m pytest integration_tests/ -v
	docker-compose -f docker-compose.test.yml down

# Code quality
format: ## Format code using black and isort
	@echo "Formatting code..."
	@for service in api-gateway tournament-api elo-service leaderboard-service review-workflow hash-verification team-management match-scheduling notification-service audit-service; do \
		echo "Formatting $$service..."; \
		docker-compose exec $$service black . --line-length 100; \
		docker-compose exec $$service isort . --profile black; \
	done
	@echo "Code formatting complete"

lint: ## Run linting checks
	@echo "Running linting checks..."
	@for service in api-gateway tournament-api elo-service leaderboard-service; do \
		echo "Linting $$service..."; \
		docker-compose exec $$service flake8 . --max-line-length=100 --exclude=migrations; \
		docker-compose exec $$service mypy . --ignore-missing-imports; \
	done
	@echo "Linting complete"

security-scan: ## Run security scans
	@echo "Running security scans..."
	@for service in api-gateway tournament-api elo-service leaderboard-service; do \
		echo "Scanning $$service..."; \
		docker-compose exec $$service bandit -r . -f json -o security_report.json; \
		docker-compose exec $$service safety check; \
	done
	@echo "Security scan complete"

# Monitoring and health checks
health: ## Check health of all services
	@echo "Checking service health..."
	@echo "========================"
	@curl -s http://localhost:8080/health | jq . || echo "API Gateway: DOWN"
	@echo ""

metrics: ## Show Prometheus metrics
	@echo "Prometheus metrics available at: http://localhost:9090"
	@echo "Grafana dashboard available at: http://localhost:3001 (admin/admin)"
	@echo "Current API Gateway metrics:"
	@curl -s http://localhost:8080/metrics | head -20

# Development helpers
shell: ## Open shell in API Gateway container
	docker-compose exec api-gateway /bin/bash

shell-service: ## Open shell in specific service (usage: make shell-service SERVICE=tournament-api)
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make shell-service SERVICE=<service-name>"; \
	else \
		docker-compose exec $(SERVICE) /bin/bash; \
	fi

redis-cli: ## Open Redis CLI
	docker-compose exec redis redis-cli -a redis_pass

psql: ## Open PostgreSQL CLI
	docker-compose exec postgres psql -U tournament_user -d tournament_db

rabbitmq-cli: ## Open RabbitMQ management CLI
	@echo "RabbitMQ Management UI: http://localhost:15672"
	@echo "Username: tournament_user"
	@echo "Password: tournament_pass"

# Data operations
seed-data: ## Load sample tournament data
	@echo "Loading sample data..."
	@echo "Creating sample tournament..."
	curl -X POST http://localhost:8080/api/v1/tournaments \
		-H "Content-Type: application/json" \
		-d '{"name": "Demo Tournament", "description": "Sample tournament for testing", "start_date": "2024-04-01T10:00:00Z", "end_date": "2024-04-30T18:00:00Z", "max_teams": 16}'
	@echo "Sample data loaded"

# Cleanup
clean: ## Clean up containers, volumes, and images
	@echo "Cleaning up..."
	docker-compose down -v
	docker system prune -f
	docker volume prune -f
	@echo "Cleanup complete"

clean-all: ## Complete cleanup including images
	@echo "Performing complete cleanup..."
	docker-compose down -v --rmi all
	docker system prune -af
	docker volume prune -f
	@echo "Complete cleanup finished"

# Performance testing
load-test: ## Run load tests against the API
	@echo "Running load tests..."
	@command -v wrk >/dev/null 2>&1 || { echo "wrk is required for load testing. Install it first."; exit 1; }
	wrk -t12 -c400 -d30s http://localhost:8080/health
	@echo "Load test complete"

# Kubernetes operations (for later)
k8s-deploy: ## Deploy to local Kubernetes
	@echo "Deploying to Kubernetes..."
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/secrets.yaml
	kubectl apply -f k8s/configmaps.yaml
	kubectl apply -f k8s/storage.yaml
	kubectl apply -f k8s/databases.yaml
	kubectl apply -f k8s/services.yaml
	kubectl apply -f k8s/deployments.yaml
	kubectl apply -f k8s/ingress.yaml
	@echo "Kubernetes deployment complete"

k8s-status: ## Check Kubernetes deployment status
	kubectl get pods -n tournament-system
	kubectl get services -n tournament-system

k8s-clean: ## Clean up Kubernetes resources
	kubectl delete namespace tournament-system

# Environment specific commands
dev: up ## Start development environment
	@echo "Development environment started"
	@echo "API Documentation: http://localhost:8080/docs"

prod-build: ## Build production images
	@echo "Building production images..."
	docker-compose -f docker-compose.prod.yml build

# Quick commands
quick-start: setup build up ## Quick start: setup, build, and run
	@echo "Tournament system is starting up..."
	@echo "Waiting for services to be ready..."
	@sleep 30
	@make health

stop: down ## Stop all services (alias for down)

# Documentation
docs: ## Generate and serve documentation
	@echo "Generating API documentation..."
	@echo "API docs available at: http://localhost:8080/docs"
	@echo "ReDoc available at: http://localhost:8080/redoc"

# Version and info
version: ## Show version information
	@echo "Tournament Management System"
	@echo "Version: 1.0.0"
	@echo "Environment: development"
	@echo "Docker Compose version:"
	@docker-compose version
	@echo "Docker version:"
	@docker version --format "{{.Server.Version}}" 