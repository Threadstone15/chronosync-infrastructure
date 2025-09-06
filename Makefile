# ChronoSync Infrastructure Makefile
# Common operations for development and testing

.PHONY: help setup start stop restart logs clean test build status

# Default target
help:
	@echo "ChronoSync Infrastructure - Available Commands:"
	@echo ""
	@echo "  setup     - Initial setup (copy .env.example to .env)"
	@echo "  start     - Start all services with build"
	@echo "  stop      - Stop all services"
	@echo "  restart   - Restart all services"
	@echo "  logs      - Show logs for all services"
	@echo "  clean     - Stop and remove all containers, networks, and volumes"
	@echo "  test      - Run infrastructure tests"
	@echo "  build     - Build all Docker images"
	@echo "  status    - Show status of all services"
	@echo ""
	@echo "  app1-logs - Show logs for app1"
	@echo "  app2-logs - Show logs for app2" 
	@echo "  app3-logs - Show logs for app3"
	@echo "  mysql-logs - Show logs for MySQL"
	@echo "  nginx-logs - Show logs for nginx_north"
	@echo ""

# Initial setup
setup:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env file from .env.example"; \
		echo "Please edit .env with your MySQL credentials"; \
	else \
		echo ".env already exists"; \
	fi

# Start all services
start: setup
	docker compose up -d --build

# Stop all services
stop:
	docker compose down

# Restart all services
restart:
	docker compose restart

# Show logs for all services
logs:
	docker compose logs -f

# Clean everything (WARNING: removes volumes)
clean:
	docker compose down -v --remove-orphans
	docker system prune -f

# Run tests
test:
	@if [ -f scripts/test-infrastructure.sh ]; then \
		chmod +x scripts/test-infrastructure.sh; \
		./scripts/test-infrastructure.sh; \
	else \
		echo "Test script not found"; \
	fi

# Build all images
build:
	docker compose build

# Show service status
status:
	docker compose ps

# Individual service logs
app1-logs:
	docker compose logs -f app1

app2-logs:
	docker compose logs -f app2

app3-logs:
	docker compose logs -f app3

mysql-logs:
	docker compose logs -f mysql

nginx-logs:
	docker compose logs -f nginx_north

south-nginx-logs:
	docker compose logs -f nginx_south

# Development helpers
dev-start: start
	@echo "Development environment started"
	@echo "Access applications at:"
	@echo "  App1: http://localhost:8080/app1/"
	@echo "  App2: http://localhost:8080/app2/"
	@echo "  App3: http://localhost:8080/app3/"
	@echo "  Internal: http://localhost:8080/internal/"

# Health check
health:
	@echo "Checking service health..."
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Quick rebuild of specific service
rebuild-app1:
	docker compose up -d --build app1

rebuild-app2:
	docker compose up -d --build app2

rebuild-app3:
	docker compose up -d --build app3

rebuild-nginx:
	docker compose up -d --build nginx_north nginx_south

# Run builder
run-builder:
	docker compose up --build builder

# Show network information
network-info:
	@echo "Docker networks:"
	@docker network ls | grep chronosync
	@echo ""
	@echo "Container network information:"
	@docker compose ps --format "table {{.Name}}\t{{.Networks}}"
