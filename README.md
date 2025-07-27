# Tournament Management System

A comprehensive tournament management system built with microservices architecture, featuring ELO rating system, result hashing, human review workflow, and real-time leaderboards.

## 🚀 Quick Start

Get the entire system running locally in minutes:

```bash
# Clone the repository
git clone <repository-url>
cd ReTurni

# Quick start (builds and starts everything)
./quick-start.sh
```

The script will:
- ✅ Check prerequisites (Docker, Docker Compose)
- ✅ Build all microservices
- ✅ Start the complete system
- ✅ Run health checks
- ✅ Test basic functionality

**System will be available at:**
- **API Gateway**: http://localhost:8080
- **API Documentation**: http://localhost:8080/docs
- **Grafana Dashboard**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **RabbitMQ Management**: http://localhost:15672

## 🏗️ Architecture Overview

### Microservices
- **api-gateway**: Main API gateway with authentication and routing
- **tournament-api**: Tournament management and deployment
- **elo-service**: ELO rating calculations and updates
- **leaderboard-service**: Real-time leaderboard management
- **review-workflow**: Human review and approval system
- **hash-verification**: Result hashing and integrity verification
- **notification-service**: Multi-channel notification system
- **team-management**: Team registration and management
- **match-scheduling**: Match scheduling and bracket management
- **audit-service**: Comprehensive audit logging

### Infrastructure
- **PostgreSQL**: Primary database with encryption
- **Redis**: Caching and session management
- **RabbitMQ**: Message queue for async processing
- **Prometheus**: Metrics and monitoring
- **Grafana**: Dashboard and visualization

## 🛠️ Development Commands

We've included a comprehensive Makefile with 30+ commands for development:

### Core Operations
```bash
make up          # Start all services
make down        # Stop all services
make restart     # Restart all services
make status      # Show service status
make logs        # Show all logs
make health      # Check service health
```

### Database Operations
```bash
make db-reset    # Reset database (WARNING: deletes data)
make db-backup   # Create database backup
make db-restore BACKUP=filename.sql  # Restore from backup
make migrate     # Run database migrations
```

### Testing
```bash
make test        # Run all tests
make test-api    # Run API tests only
make test-elo    # Run ELO service tests
make test-integration  # Run integration tests
```

### Code Quality
```bash
make format      # Format code with black/isort
make lint        # Run linting checks
make security-scan  # Run security scans
```

### Development Helpers
```bash
make shell       # Open shell in API Gateway
make shell-service SERVICE=tournament-api  # Open shell in specific service
make redis-cli   # Open Redis CLI
make psql        # Open PostgreSQL CLI
```

### Monitoring
```bash
make metrics     # Show Prometheus metrics
make health      # Check all service health
```

### Cleanup
```bash
make clean       # Clean containers and volumes
make clean-all   # Complete cleanup including images
```

See `make help` for the complete list of available commands.

## 📱 API Documentation

Once the system is running, comprehensive API documentation is available:

- **Swagger UI**: http://localhost:8080/docs
- **ReDoc**: http://localhost:8080/redoc
- **OpenAPI Spec**: http://localhost:8080/openapi.json

### Authentication

The system uses JWT authentication. Default admin credentials for testing:
- **Email**: admin@tournament.com
- **Password**: admin123

Example login:
```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@tournament.com", "password": "admin123"}'
```

### Creating a Tournament

```bash
curl -X POST http://localhost:8080/api/v1/tournaments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "name": "Spring Championship 2024",
    "description": "Annual spring tournament",
    "start_date": "2024-04-01T10:00:00Z",
    "end_date": "2024-04-30T18:00:00Z",
    "max_teams": 32,
    "tournament_type": "single_elimination"
  }'
```

## 🎯 Core Features

### Tournament Management
- ✅ Tournament deployment and management
- ✅ Multiple tournament types (single elimination, round robin, etc.)
- ✅ Pause/resume functionality
- ✅ Tournament configuration management

### ELO Rating System
- ✅ Tournament-specific ELO tracking
- ✅ K-factor variations based on match importance
- ✅ Upset handling and rating adjustments
- ✅ Historical rating tracking

### Security & Data Integrity
- ✅ SHA-256 result hashing with timestamps
- ✅ Data integrity verification and tampering detection
- ✅ Comprehensive audit logging
- ✅ Role-based access control
- ✅ API rate limiting

### Real-time Features
- ✅ Live leaderboard updates
- ✅ WebSocket support for real-time notifications
- ✅ Multi-channel notifications (email, SMS, push)

### Human Review Workflow
- ✅ Result approval/rejection system
- ✅ Dispute handling
- ✅ Evidence management (including video)
- ✅ Batch processing capabilities

### Team & Match Management
- ✅ Team registration and approval
- ✅ Roster management
- ✅ Match scheduling with conflict detection
- ✅ Referee assignment
- ✅ Bracket generation

## 📊 Monitoring & Observability

### Grafana Dashboards
Access comprehensive monitoring at http://localhost:3001:
- System health overview
- Request rates and response times
- Error rates and service availability
- Resource utilization metrics

### Prometheus Metrics
Available at http://localhost:9090:
- HTTP request metrics
- Service-specific metrics
- Infrastructure metrics
- Custom business metrics

### Health Checks
Every service provides health check endpoints:
```bash
curl http://localhost:8080/health
```

## 🐳 Docker & Kubernetes

### Local Development (Docker Compose)
The system is designed for local development with Docker Compose:
```bash
docker-compose up -d  # Start all services
docker-compose down   # Stop all services
```

### Kubernetes Deployment
Kubernetes manifests are provided in the `k8s/` directory:
```bash
make k8s-deploy    # Deploy to local Kubernetes
make k8s-status    # Check deployment status
make k8s-clean     # Clean up resources
```

## 🧪 Testing

### Test Suites
- **Unit Tests**: Individual service testing
- **Integration Tests**: Service-to-service communication
- **API Tests**: End-to-end API testing
- **Load Tests**: Performance and scalability testing

### Running Tests
```bash
make test              # Run all tests
make test-integration  # Run integration tests only
make load-test         # Run load tests (requires wrk)
```

## 🔧 Configuration

### Environment Variables
Key configuration options:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:port/db
REDIS_URL=redis://:pass@host:port/db

# Authentication
JWT_SECRET=your-secret-key
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30

# Service URLs
ELO_SERVICE_URL=http://elo-service:8080
LEADERBOARD_SERVICE_URL=http://leaderboard-service:8080
```

### Feature Flags
Configure tournament features:
```json
{
  "elo_enabled": true,
  "hash_verification": true,
  "human_review": true,
  "k_factor": 32,
  "initial_elo": 1500
}
```

## 🚀 Deployment

### Production Considerations
- SSL/TLS certificates (Let's Encrypt integration ready)
- Environment-specific configuration
- Database encryption and backup strategies
- Monitoring and alerting setup
- Auto-scaling configuration

### Kubernetes Production
```bash
# Build production images
make prod-build

# Deploy to production Kubernetes
make k8s-deploy
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test`)
5. Format code (`make format`)
6. Run security scan (`make security-scan`)
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

## 📋 System Requirements

### Development
- Docker 20.10+
- Docker Compose 2.0+
- 8GB RAM minimum
- 10GB disk space

### Production
- Kubernetes 1.20+
- PostgreSQL 13+
- Redis 6+
- RabbitMQ 3.8+

## 🔍 Troubleshooting

### Common Issues

**Services not starting:**
```bash
make logs                    # Check all logs
make logs-service SERVICE=postgres  # Check specific service
```

**Database connection issues:**
```bash
make db-reset               # Reset database
make health                 # Check health status
```

**Permission issues:**
```bash
chmod +x quick-start.sh     # Make script executable
sudo chown -R $USER:$USER . # Fix ownership
```

### Getting Help
- Check service logs: `make logs`
- Verify health status: `make health`
- Review API documentation: http://localhost:8080/docs
- Monitor system metrics: http://localhost:3001

## 📄 License

MIT License - see LICENSE file for details

---

**Built with ❤️ for tournament organizers worldwide** 