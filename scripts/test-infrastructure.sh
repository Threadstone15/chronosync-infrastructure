#!/bin/bash
# Comprehensive testing script for ChronoSync Infrastructure

set -e

echo "🚀 Starting ChronoSync Infrastructure Tests..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        return 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "ℹ $1"
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_status 1 "Docker is not installed"
    exit 1
fi
print_status 0 "Docker is available"

if ! command -v docker compose &> /dev/null; then
    print_status 1 "Docker Compose is not installed"
    exit 1
fi
print_status 0 "Docker Compose is available"

# Check if .env exists
if [ ! -f .env ]; then
    print_warning ".env file not found, copying from .env.example"
    cp .env.example .env
    print_info "Please edit .env with your credentials and run the test again"
    exit 1
fi
print_status 0 ".env file exists"

# Start infrastructure
print_info "Starting infrastructure..."
docker compose up -d --build

# Wait for services to be ready
print_info "Waiting for services to be ready..."
sleep 30

# Test 1: Check if all services are running
print_info "Testing service health..."

services=("mysql_db" "nginx_north" "nginx_south" "app1" "app2" "app3" "dnsmasq" "ntp_server")
for service in "${services[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "$service"; then
        print_status 0 "Service $service is running"
    else
        print_status 1 "Service $service is not running"
    fi
done

# Test 2: HTTP endpoint tests
print_info "Testing HTTP endpoints..."

# Test north nginx
if curl -s -f http://localhost:8080 > /dev/null; then
    print_status 0 "North nginx is responding"
else
    print_status 1 "North nginx is not responding"
fi

# Test application endpoints
for app in app1 app2 app3; do
    if curl -s -f "http://localhost:8080/$app/" > /dev/null; then
        print_status 0 "$app endpoint is responding"
    else
        print_status 1 "$app endpoint is not responding"
    fi
done

# Test internal routing
if curl -s -f http://localhost:8080/internal/health/ > /dev/null; then
    print_status 0 "Internal routing is working"
else
    print_status 1 "Internal routing is not working"
fi

# Test 3: DNS resolution
print_info "Testing DNS resolution..."

dns_names=("app1.local" "app2.local" "app3.local" "mysql.local")
for name in "${dns_names[@]}"; do
    if docker exec dnsmasq nslookup "$name" > /dev/null 2>&1; then
        print_status 0 "DNS resolution for $name is working"
    else
        print_status 1 "DNS resolution for $name is not working"
    fi
done

# Test 4: MySQL connectivity
print_info "Testing MySQL connectivity..."

if docker exec mysql_db mysqladmin ping > /dev/null 2>&1; then
    print_status 0 "MySQL is responding to ping"
else
    print_status 1 "MySQL is not responding to ping"
fi

# Test 5: Network connectivity between services
print_info "Testing network connectivity..."

if docker exec app1 ping -c 3 mysql_db > /dev/null 2>&1; then
    print_status 0 "app1 can reach mysql"
else
    print_status 1 "app1 cannot reach mysql"
fi

if docker exec nginx_north ping -c 3 app1 > /dev/null 2>&1; then
    print_status 0 "nginx_north can reach app1"
else
    print_status 1 "nginx_north cannot reach app1"
fi

# Test 6: Volume persistence
print_info "Testing volume persistence..."

volumes=("mysql_data" "app1_data" "app2_data" "app3_data")
for volume in "${volumes[@]}"; do
    if docker volume ls | grep -q "$volume"; then
        print_status 0 "Volume $volume exists"
    else
        print_status 1 "Volume $volume does not exist"
    fi
done

# Show service logs if any test failed
if [ $? -ne 0 ]; then
    print_warning "Some tests failed. Showing recent logs..."
    docker compose logs --tail=20
fi

print_info "Test completed. Infrastructure status:"
docker compose ps

echo ""
print_info "To clean up: docker compose down -v"
print_info "To view logs: docker compose logs [service_name]"
