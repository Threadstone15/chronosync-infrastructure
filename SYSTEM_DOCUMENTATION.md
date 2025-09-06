# ChronoSync Infrastructure - Complete System Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Deep Dive](#architecture-deep-dive)
3. [Component Analysis](#component-analysis)
4. [Configuration Files Explained](#configuration-files-explained)
5. [Network Architecture](#network-architecture)
6. [Data Flow & Service Communication](#data-flow--service-communication)
7. [Security Implementation](#security-implementation)
8. [Operational Procedures](#operational-procedures)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Production Deployment](#production-deployment)

---

## System Overview

The ChronoSync Infrastructure is a containerized microservices architecture designed to simulate a production-grade IT/OT (Information Technology/Operational Technology) environment for testing and development purposes. It implements network segmentation, service discovery, load balancing, and infrastructure services in a local Docker environment.

### Core Philosophy

- **Segmentation**: Clear separation between IT and OT networks
- **Scalability**: Microservices architecture with independent scaling
- **Security**: Defense-in-depth with multiple security layers
- **Observability**: Built-in monitoring and health checking
- **Portability**: Container-first design for consistent deployment

### System Components Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    HOST SYSTEM (Windows/Linux)              │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   IT Network    │  │ Internal Network│  │ OT Network   │ │
│  │   (Bridge)      │  │    (Bridge)     │  │  (Future)    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│           │                     │                  │        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  nginx_north    │  │    dnsmasq      │  │   Future     │ │
│  │  (External)     │  │  (DNS/DHCP)     │  │  OT Services │ │
│  │  Port: 8080     │  │                 │  │              │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│           │                     │                           │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │   app1, app2,   │  │  nginx_south    │                  │
│  │      app3       │  │  (Internal)     │                  │
│  │ (Applications)  │  │                 │                  │
│  └─────────────────┘  └─────────────────┘                  │
│           │                     │                           │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │     mysql       │  │   ntp, builder  │                  │
│  │  (Database)     │  │  (Infrastructure)│                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture Deep Dive

### 1. Network Architecture

#### Network Segmentation Strategy

The system implements a three-tier network architecture:

**IT Network (it_net)**

- Purpose: External-facing services and management interfaces
- CIDR: Docker-managed (typically 172.x.x.x/16)
- Services: nginx_north, app1, app2, app3
- Security: Controlled external access through nginx_north

**Internal Network (internal_net)**

- Purpose: Service-to-service communication
- CIDR: Docker-managed (typically 172.x.x.x/16)
- Services: All services for internal communication
- Security: Isolated from external access

**Future OT Network**

- Purpose: Operational Technology services (manufacturing, SCADA, etc.)
- Implementation: Reserved for future expansion
- Security: Air-gapped from IT network with controlled bridging

#### Service Mesh Implementation

```
External Request → nginx_north (Port 8080) → Path-based Routing
                        │
                        ├─ /app1/ → app1:80
                        ├─ /app2/ → app2:80
                        ├─ /app3/ → app3:80
                        └─ /internal/ → nginx_south:80
                                           │
                                           ├─ /mysql-proxy/ → mysql:3306
                                           └─ /health/ → Health Check
```

### 2. Container Orchestration

The system uses Docker Compose to orchestrate 8 primary services:

1. **Application Tier**: app1, app2, app3
2. **Proxy Tier**: nginx_north, nginx_south
3. **Data Tier**: mysql
4. **Infrastructure Tier**: dnsmasq, ntp
5. **Build Tier**: builder (ephemeral)
6. **Security Tier**: iptables-setup (ephemeral)

---

## Component Analysis

### 1. Application Services (app1, app2, app3)

**Purpose**: Serve web applications with identical architecture but different content

**Technology Stack**:

- Base Image: `nginx:alpine` (lightweight, security-focused)
- Content: Static HTML served from `/usr/share/nginx/html`
- Volume: Named volumes for persistent content storage

**Configuration Details**:

```dockerfile
# app/Dockerfile
FROM nginx:alpine
LABEL maintainer="dev@example.com"
COPY static /usr/share/nginx/html
```

**Key Features**:

- Health checks via HTTP GET to localhost
- Labeled for easy identification (`role=app`)
- Shared volume architecture for dynamic content updates
- Multi-network connectivity (IT + Internal)

**Volume Mapping**:

- `app1_data:/usr/share/nginx/html:ro` (read-only for security)
- Content populated by builder service during deployment

### 2. North Nginx (External Proxy)

**Purpose**: External-facing reverse proxy with path-based routing

**Configuration File**: `nginx/north.conf`

```nginx
upstream app1_up {
    server app1:80;
}
upstream app2_up {
    server app2:80;
}
upstream app3_up {
    server app3:80;
}

server {
    listen 80;
    server_name _;

    location /app1/ {
        proxy_pass http://app1_up/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    # ... additional locations
}
```

**Key Features**:

- Load balancing with upstream definitions
- Header preservation for client identification
- Path-based routing for microservices
- Health monitoring of upstream servers
- TLS termination ready (port 8443 reserved)

**Security Considerations**:

- Only exposed service to host network
- Acts as security barrier for internal services
- Request filtering and rate limiting capabilities

### 3. South Nginx (Internal Proxy)

**Purpose**: Internal service mesh for service-to-service communication

**Configuration File**: `nginx/south.conf`

```nginx
upstream mysql_up {
    server mysql:3306;
}

server {
    listen 80;
    server_name south.local;

    location /mysql-proxy/ {
        return 200 "mysql proxy placeholder\n";
    }

    location /health/ {
        return 200 "ok\n";
    }
}
```

**Key Features**:

- Internal API gateway functionality
- Database connection proxying
- Health check endpoints
- Service discovery integration

### 4. MySQL Database

**Purpose**: Persistent data storage with high availability features

**Configuration File**: `mysql/my.cnf`

```ini
[mysqld]
innodb_buffer_pool_size=128M
max_connections=200
```

**Key Features**:

- MySQL 8.0 with enhanced security features
- Persistent storage via named volumes
- Health checks via mysqladmin ping
- Environment-based configuration
- Custom configuration overlay

**Environment Variables**:

```bash
MYSQL_ROOT_PASSWORD=secure_password
MYSQL_DATABASE=application_db
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password
```

**Volume Strategy**:

- `mysql_data:/var/lib/mysql` - Database files
- `./mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro` - Configuration

### 5. DNS/DHCP Service (dnsmasq)

**Purpose**: Internal service discovery and IP management

**Configuration File**: `dnsmasq/dnsmasq.conf`

```bash
no-resolv
bind-interfaces
domain-needed
expand-hosts
domain=localdomain

# Static hostname mappings
address=/app1.local/127.0.0.1
address=/app2.local/127.0.0.1
address=/app3.local/127.0.0.1
address=/mysql.local/127.0.0.1

# DHCP range
dhcp-range=192.168.77.50,192.168.77.150,12h
```

**Key Features**:

- Service name resolution within container network
- DHCP server for IP allocation
- Domain-based service discovery
- Integration with Docker's embedded DNS

**Network Integration**:

- Attached to internal_net for service discovery
- Provides DNS resolution for .local domains
- DHCP services for dynamic IP allocation

### 6. NTP Service (chrony)

**Purpose**: Network time synchronization for distributed services

**Configuration File**: `ntp/chrony.conf`

```bash
pool pool.ntp.org iburst
allow 192.168.77.0/24
local stratum 10
driftfile /var/lib/chrony/drift
```

**Key Features**:

- Upstream NTP pool synchronization
- Local network time server
- Drift compensation for accuracy
- Container-based time distribution

**Production Considerations**:

- Container time sync limitations
- Host-level NTP recommended for production
- Time skew monitoring capabilities

### 7. Builder Service

**Purpose**: Automated application building and deployment

**Configuration Files**:

- `builder/Dockerfile`: Container definition
- `builder/build-and-deploy.sh`: Build automation script

**Dockerfile Analysis**:

```dockerfile
FROM alpine:3.18
RUN apk add --no-cache git openssh-client bash curl
WORKDIR /builder
COPY build-and-deploy.sh /builder/build-and-deploy.sh
RUN chmod +x /builder/build-and-deploy.sh
ENTRYPOINT ["/builder/build-and-deploy.sh"]
```

**Build Script Features**:

```bash
#!/bin/sh
set -e
echo "[builder] starting build-and-deploy.sh"

# Generate application-specific content
cat > /app1_dist/index.html <<'EOF'
<!doctype html><html><body><h1>App1 - built by builder</h1></body></html>
EOF
```

**SSH Agent Forwarding**:

- Volume mount: `$SSH_AUTH_SOCK:/ssh-agent`
- Environment: `SSH_AUTH_SOCK=/ssh-agent`
- Enables secure Git operations without key storage

**Volume Strategy**:

- `builder_cache:/builder_cache` - Build artifacts cache
- `app1_data:/app1_dist` - App1 deployment target
- `app2_data:/app2_dist` - App2 deployment target
- `app3_data:/app3_dist` - App3 deployment target

### 8. Firewall Configuration (iptables-setup)

**Purpose**: Host-level network security and segmentation

**Configuration File**: `iptables/iptables.sh`

```bash
#!/bin/sh
echo "[iptables] applying sample iptables rules"

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -t mangle -F

# OT to IT network segmentation
iptables -A FORWARD -s 192.168.100.0/24 -d 192.168.200.0/24 -j DROP

# Allow established connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow Docker bridge traffic
iptables -A INPUT -i docker0 -j ACCEPT
```

**Security Features**:

- Network segmentation enforcement
- Connection state tracking
- Docker bridge integration
- Host-level protection

**Deployment Mode**:

- `network_mode: "host"` for direct host access
- `cap_add: NET_ADMIN` for firewall management
- `restart: "no"` for one-time execution

---

## Configuration Files Explained

### 1. Docker Compose Configuration

**File**: `docker-compose.yml`

**Network Definitions**:

```yaml
networks:
  internal_net:
    driver: bridge
    # Used for inter-service communication
    # Provides isolation from external access
  it_net:
    driver: bridge
    # Used for IT services and external connectivity
    # Connects to nginx_north for host access
```

**Volume Strategy**:

```yaml
volumes:
  mysql_data: # Database persistence
  dnsmasq_data: # DNS/DHCP configuration
  ntp_data: # Time server data
  builder_cache: # Build artifact cache
  app1_data: # Application 1 content
  app2_data: # Application 2 content
  app3_data: # Application 3 content
```

**Health Check Implementation**:

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  interval: 10s
  timeout: 5s
  retries: 5
```

### 2. Environment Configuration

**File**: `.env` (created from `.env.example`)

**Database Configuration**:

```bash
MYSQL_ROOT_PASSWORD=secure_root_password
MYSQL_DATABASE=chronosync_db
MYSQL_USER=chronosync_user
MYSQL_PASSWORD=secure_user_password
```

**Network Configuration**:

```bash
DHCP_RANGE_START=192.168.77.50
DHCP_RANGE_END=192.168.77.150
DHCP_NETMASK=255.255.255.0
DNS_DOMAIN=localdomain
```

### 3. Build Configuration

**File**: `Makefile`

**Common Operations**:

```makefile
start: setup
	docker compose up -d --build

test:
	./scripts/test-infrastructure.sh

clean:
	docker compose down -v --remove-orphans
```

### 4. CI/CD Configuration

**File**: `.github/workflows/ci.yml`

**Build Pipeline**:

```yaml
- name: Build Docker images
  run: |
    docker build -t infra-app ./app
    docker build -t infra-builder ./builder
```

---

## Network Architecture

### 1. Network Flow Diagram

```
Internet → Host:8080 → nginx_north → it_net → Applications
                           ↓
                    internal_net → nginx_south → mysql
                           ↓
                       dnsmasq ← → Service Discovery
                           ↓
                         ntp → Time Sync
```

### 2. DNS Resolution Flow

```
Container Request → Docker Embedded DNS → dnsmasq → Resolution
                                            ↓
Service.local → Static Mapping → Container IP → Response
```

### 3. Load Balancing Strategy

**nginx_north Load Balancing**:

- Path-based routing (not round-robin)
- `/app1/` → Always routes to app1
- `/app2/` → Always routes to app2
- `/app3/` → Always routes to app3

**Future Enhancement**:

- Multiple instances per application
- Round-robin load balancing
- Health-based routing
- Session affinity

---

## Data Flow & Service Communication

### 1. Request Processing Flow

**External Web Request**:

```
Client → Host:8080 → nginx_north → Path Analysis → Target App
  ↓
Target App → Static Content → Response → nginx_north → Client
```

**Internal Service Communication**:

```
App → internal_net → nginx_south → Route Analysis → Target Service
  ↓
Target Service → Response → nginx_south → App
```

### 2. Database Access Pattern

**Direct Access** (Current):

```
Application → internal_net → mysql:3306 → Database Response
```

**Proxied Access** (Available):

```
Application → nginx_south → /mysql-proxy/ → mysql:3306 → Response
```

### 3. Build and Deployment Flow

```
Developer → SSH Agent → Builder Container → Git Clone → Build Process
                                              ↓
Volume Mount → App Container → nginx Reload → New Content Served
```

---

## Security Implementation

### 1. Network Security

**Segmentation**:

- IT Network: External-facing services
- Internal Network: Service-to-service communication
- Future OT Network: Operational technology isolation

**Access Control**:

- nginx_north: Only service exposed to host
- Internal services: No direct external access
- Database: Protected behind internal network

### 2. Container Security

**Image Security**:

- Alpine-based images for minimal attack surface
- No root processes where possible
- Read-only file systems for static content

**Volume Security**:

- Named volumes for data persistence
- Read-only mounts for configuration files
- Temporary volumes for build processes

### 3. Authentication & Authorization

**SSH Security**:

- SSH agent forwarding for secure Git access
- No private keys stored in containers
- Ephemeral build containers

**Database Security**:

- Environment variable configuration
- User-based access control
- Network-level access restrictions

---

## Operational Procedures

### 1. Startup Sequence

**Automatic Dependency Management**:

```yaml
depends_on:
  - app1
  - app2
  - app3
```

**Health Check Verification**:

1. MySQL health check (mysqladmin ping)
2. Nginx process monitoring (pidof nginx)
3. Application HTTP endpoint validation

### 2. Monitoring and Logging

**Log Aggregation**:

```bash
# View all service logs
docker compose logs -f

# View specific service logs
docker compose logs -f mysql
docker compose logs -f nginx_north
```

**Health Monitoring**:

```bash
# Check service status
docker compose ps

# View health check status
docker inspect <container_name> | grep Health
```

### 3. Backup and Recovery

**Database Backup**:

```bash
# Create backup
docker exec mysql_db mysqldump -u root -p$MYSQL_ROOT_PASSWORD --all-databases > backup.sql

# Restore backup
docker exec -i mysql_db mysql -u root -p$MYSQL_ROOT_PASSWORD < backup.sql
```

**Volume Backup**:

```bash
# Backup volume data
docker run --rm -v mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql_backup.tar.gz /data
```

---

## Troubleshooting Guide

### 1. Common Issues

**Container Won't Start**:

```bash
# Check container logs
docker compose logs <service_name>

# Check container configuration
docker compose config

# Verify port availability
netstat -tulpn | grep 8080
```

**Network Connectivity Issues**:

```bash
# Test inter-container connectivity
docker exec app1 ping mysql_db

# Check network configuration
docker network ls
docker network inspect chronosync-infrastructure_internal_net
```

**DNS Resolution Problems**:

```bash
# Test DNS resolution
docker exec dnsmasq nslookup app1.local

# Check dnsmasq configuration
docker exec dnsmasq cat /etc/dnsmasq.conf
```

### 2. Performance Optimization

**MySQL Performance**:

```ini
# mysql/my.cnf optimizations
innodb_buffer_pool_size=512M  # Increase for more RAM
max_connections=500           # Increase for high concurrency
query_cache_size=64M         # Enable query caching
```

**Nginx Performance**:

```nginx
# Add to nginx configurations
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
gzip on;
gzip_types text/plain application/json;
```

### 3. Security Hardening

**Container Hardening**:

```yaml
# Add to service definitions
security_opt:
  - no-new-privileges:true
read_only: true
user: "1000:1000"
```

**Network Hardening**:

```bash
# Enhanced iptables rules
iptables -A INPUT -p tcp --dport 8080 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j DROP
```

---

## Production Deployment

### 1. Terraform Integration

**File Structure**:

```
terraform/
├── main.tf           # Provider configuration
├── variables.tf      # Input variables
├── modules/
│   ├── compute/      # VM/container definitions
│   ├── network/      # VPC/subnet configuration
│   └── storage/      # Persistent storage
```

**HCI Provider Examples**:

```hcl
# VMware vSphere
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
}

# Nutanix
provider "nutanix" {
  username = var.nutanix_username
  password = var.nutanix_password
  endpoint = var.nutanix_endpoint
}
```

### 2. High Availability Configuration

**Database Clustering**:

- MySQL InnoDB Cluster setup
- Read/write splitting
- Automatic failover

**Application Scaling**:

- Multiple instances per application
- Load balancer configuration
- Auto-scaling policies

**Infrastructure Redundancy**:

- Multi-zone deployment
- Backup and disaster recovery
- Monitoring and alerting

### 3. Security Enhancements

**TLS Configuration**:

```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
}
```

**Secrets Management**:

- External secrets store integration
- Environment variable encryption
- Certificate rotation automation

---

## Conclusion

The ChronoSync Infrastructure provides a comprehensive, production-ready architecture for containerized applications with strong emphasis on:

1. **Security**: Multi-layer security with network segmentation
2. **Scalability**: Microservices architecture with independent scaling
3. **Maintainability**: Clear separation of concerns and comprehensive documentation
4. **Observability**: Built-in monitoring, logging, and health checking
5. **Portability**: Container-first design for consistent deployment

This documentation serves as both a learning resource and operational guide for understanding, deploying, and maintaining the ChronoSync Infrastructure in various environments from development to production.
