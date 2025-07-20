# Tournament Deployment Service

A comprehensive tournament management system built with microservices architecture, featuring ELO rating system, result hashing, human review workflow, and real-time leaderboards.

## Architecture Overview

### Microservices
- **tournament-api**: Main API gateway and tournament management
- **elo-service**: ELO rating calculations and updates
- **leaderboard-svc**: Real-time leaderboard management
- **review-workflow**: Human review and approval system
- **hash-verification**: Result hashing and integrity verification
- **notification-svc**: Multi-channel notification system
- **team-management**: Team registration and management
- **match-scheduling**: Match scheduling and bracket management
- **audit-service**: Comprehensive audit logging

### Infrastructure
- **Kubernetes**: Container orchestration and scaling
- **PostgreSQL**: Primary database for tournament data
- **Redis**: Caching and session management
- **RabbitMQ**: Message queue for async processing
- **Prometheus**: Metrics and monitoring
- **Grafana**: Dashboard and visualization
- **Nginx**: Load balancer and API gateway

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Helm 3.x

### Local Development (Docker Compose)
```bash
# Clone the repository
git clone <repository-url>
cd tournament-service

# Start all services
docker-compose up -d

# Access the application
# API Gateway: http://localhost:8080
# Admin Dashboard: http://localhost:3000
# Grafana: http://localhost:3001
```

### Production Deployment (Kubernetes)
```bash
# Deploy to Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmaps.yaml
kubectl apply -f k8s/storage.yaml
kubectl apply -f k8s/databases.yaml
kubectl apply -f k8s/services.yaml
kubectl apply -f k8s/deployments.yaml
kubectl apply -f k8s/ingress.yaml

# Or use Helm
helm install tournament-service ./helm/tournament-service
```

## Features

### Core Functionality
- ✅ Tournament deployment and management
- ✅ ELO rating system with tournament-specific tracking
- ✅ SHA-256 result hashing with timestamps
- ✅ Human review workflow for result approval
- ✅ Real-time leaderboards with live updates
- ✅ Team registration and management
- ✅ Match scheduling and bracket generation
- ✅ Multi-channel notification system
- ✅ Comprehensive audit logging

### Security & Compliance
- ✅ Data integrity verification
- ✅ Role-based access control
- ✅ API rate limiting
- ✅ Audit trail preservation
- ✅ Encrypted data storage

### Scalability
- ✅ Horizontal pod autoscaling
- ✅ Load balancing
- ✅ Database connection pooling
- ✅ Caching strategies
- ✅ Message queue for async processing

## API Documentation

The API documentation is available at:
- Swagger UI: http://localhost:8080/api/docs
- OpenAPI Spec: http://localhost:8080/api/openapi.json

## Monitoring

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001
- **Kibana**: http://localhost:5601

## Development

### Running Tests
```bash
# Run all tests
make test

# Run specific service tests
make test-api
make test-elo
make test-leaderboard
```

### Code Quality
```bash
# Lint code
make lint

# Format code
make format

# Security scan
make security-scan
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details 