#!/bin/bash

# Tournament Management System - Quick Start Script
# This script sets up and starts the complete local development environment

set -e

echo "=========================================="
echo "Tournament Management System - Quick Start"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"

# Setup environment
echo -e "${BLUE}Setting up environment...${NC}"
make setup

# Build all services
echo -e "${BLUE}Building all services...${NC}"
make build

# Start the system
echo -e "${BLUE}Starting tournament management system...${NC}"
make up

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 30

# Health check
echo -e "${BLUE}Checking service health...${NC}"
make health

# Show service status
echo -e "${BLUE}Service status:${NC}"
make status

# Show available URLs
echo ""
echo "=========================================="
echo -e "${GREEN}🎉 System is ready!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}Available Services:${NC}"
echo "• API Gateway: http://localhost:8080"
echo "• API Documentation: http://localhost:8080/docs"
echo "• Health Check: http://localhost:8080/health"
echo "• Grafana Dashboard: http://localhost:3001 (admin/admin)"
echo "• Prometheus: http://localhost:9090"
echo "• RabbitMQ Management: http://localhost:15672 (tournament_user/tournament_pass)"
echo ""

# Test basic functionality
echo -e "${BLUE}Testing basic functionality...${NC}"

# Test health endpoint
echo "Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:8080/health || echo "failed")
if [[ $HEALTH_RESPONSE == *"healthy"* ]]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${YELLOW}⚠ Health check returned: $HEALTH_RESPONSE${NC}"
fi

# Test authentication endpoint
echo "Testing authentication..."
AUTH_RESPONSE=$(curl -s -X POST http://localhost:8080/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email": "admin@tournament.com", "password": "admin123"}' || echo "failed")

if [[ $AUTH_RESPONSE == *"access_token"* ]]; then
    echo -e "${GREEN}✓ Authentication test passed${NC}"
    
    # Extract token for further testing
    TOKEN=$(echo $AUTH_RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['access_token'])" 2>/dev/null || echo "")
    
    if [ ! -z "$TOKEN" ]; then
        echo "Testing tournament creation..."
        TOURNAMENT_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/tournaments \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d '{"name": "Test Tournament", "description": "Quick start test tournament", "start_date": "2024-04-01T10:00:00Z", "end_date": "2024-04-30T18:00:00Z", "max_teams": 8}' || echo "failed")
        
        if [[ $TOURNAMENT_RESPONSE == *"Test Tournament"* ]]; then
            echo -e "${GREEN}✓ Tournament creation test passed${NC}"
        else
            echo -e "${YELLOW}⚠ Tournament creation test failed: $TOURNAMENT_RESPONSE${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Authentication test failed: $AUTH_RESPONSE${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Quick Start Complete!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Visit http://localhost:8080/docs to explore the API"
echo "2. Check http://localhost:3001 for Grafana monitoring"
echo "3. Run 'make logs' to see all service logs"
echo "4. Run 'make help' to see all available commands"
echo ""
echo -e "${BLUE}To stop the system:${NC}"
echo "make down"
echo ""
echo -e "${BLUE}To restart the system:${NC}"
echo "make restart"
echo ""
echo -e "${BLUE}For development:${NC}"
echo "• make shell - open shell in API Gateway"
echo "• make logs-service SERVICE=tournament-api - view specific service logs"
echo "• make test - run all tests"
echo ""

# Save useful information
cat > .env.local << EOF
# Tournament Management System - Local Environment
API_GATEWAY_URL=http://localhost:8080
GRAFANA_URL=http://localhost:3001
PROMETHEUS_URL=http://localhost:9090
RABBITMQ_URL=http://localhost:15672

# Credentials
ADMIN_EMAIL=admin@tournament.com
ADMIN_PASSWORD=admin123
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin
RABBITMQ_USER=tournament_user
RABBITMQ_PASSWORD=tournament_pass
EOF

echo -e "${GREEN}Environment configuration saved to .env.local${NC}"
echo "" 