# Configuration Files Deep Dive

## Table of Contents

1. [Docker Compose Configuration](#docker-compose-configuration)
2. [Nginx Configurations](#nginx-configurations)
3. [Database Configuration](#database-configuration)
4. [DNS/DHCP Configuration](#dnsdhcp-configuration)
5. [NTP Configuration](#ntp-configuration)
6. [Build Configuration](#build-configuration)
7. [Security Configuration](#security-configuration)
8. [Environment Configuration](#environment-configuration)

---

## Docker Compose Configuration

### File: `docker-compose.yml`

#### Version Declaration

```yaml
version: "3.8"
```

- Uses Docker Compose file format version 3.8
- Supports advanced features like health checks and named volumes
- Compatible with Docker Engine 19.03.0+

#### MySQL Service Configuration

```yaml
mysql:
  image: mysql:8.0 # Official MySQL 8.0 image
  container_name: mysql_db # Fixed container name for consistent DNS
  env_file: .env # Load environment variables from .env file
  environment: # Override/add environment variables
    MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    MYSQL_DATABASE: ${MYSQL_DATABASE}
    MYSQL_USER: ${MYSQL_USER}
    MYSQL_PASSWORD: ${MYSQL_PASSWORD}
  volumes:
    - mysql_data:/var/lib/mysql # Persistent data storage
    - ./mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro # Custom configuration (read-only)
  networks:
    - internal_net # Connected to internal network only
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval: 10s # Check every 10 seconds
    timeout: 5s # Timeout after 5 seconds
    retries: 5 # Retry 5 times before marking unhealthy
```

**Key Design Decisions:**

- Uses named volume for data persistence
- Custom configuration through volume mount
- Health check using mysqladmin for MySQL-specific validation
- Only accessible from internal network for security

#### Application Services (app1, app2, app3)

```yaml
app1:
  build:
    context: ./app # Build context directory
    dockerfile: Dockerfile # Dockerfile name
  container_name: app1 # Fixed name for DNS resolution
  volumes:
    - app1_data:/usr/share/nginx/html:ro # Read-only mount for security
  networks:
    - internal_net # For service-to-service communication
    - it_net # For external access via nginx_north
  labels:
    - "role=app" # Label for identification and filtering
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost/ || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 3
```

**Multi-Network Strategy:**

- `internal_net`: For communication with database and internal services
- `it_net`: For access from nginx_north (external proxy)

#### North Nginx (External Proxy)

```yaml
nginx_north:
  image: nginx:alpine # Lightweight Alpine-based image
  container_name: nginx_north # Fixed name for DNS
  volumes:
    - ./nginx/north.conf:/etc/nginx/conf.d/default.conf:ro
  ports:
    - "8080:80" # Expose to host on port 8080
    - "8443:443" # Reserved for future TLS
  networks:
    - it_net # Access to applications
    - internal_net # Access to internal services
  depends_on: # Wait for apps to be ready
    - app1
    - app2
    - app3
```

**Port Strategy:**

- 8080: HTTP access from host
- 8443: Reserved for HTTPS (future TLS implementation)

#### Volume Definitions

```yaml
volumes:
  mysql_data: # Database persistence
  dnsmasq_data: # DNS/DHCP configuration persistence
  ntp_data: # NTP server data
  builder_cache: # Build artifact cache
  app1_data: # Application 1 content
  app2_data: # Application 2 content
  app3_data: # Application 3 content
```

**Volume Strategy:**

- Named volumes for portability across environments
- Automatic management by Docker
- Persistent across container restarts and updates

#### Network Definitions

```yaml
networks:
  internal_net:
    driver: bridge # Standard bridge network for container communication
  it_net:
    driver: bridge # Separate network for IT services
```

**Network Segmentation:**

- `internal_net`: All services for comprehensive communication
- `it_net`: Only external-facing services and applications

---

## Nginx Configurations

### File: `nginx/north.conf` (External Proxy)

#### Upstream Definitions

```nginx
upstream app1_up {
    server app1:80;     # Container name resolves via Docker DNS
}
upstream app2_up {
    server app2:80;
}
upstream app3_up {
    server app3:80;
}
```

**Benefits:**

- Health checking of backend servers
- Easy addition of multiple servers per upstream
- Load balancing capabilities (round-robin by default)

#### Server Configuration

```nginx
server {
    listen 80;          # Listen on HTTP port
    server_name _;      # Accept any hostname

    location /app1/ {
        proxy_pass http://app1_up/;           # Proxy to upstream
        proxy_set_header Host $host;          # Preserve original Host header
        proxy_set_header X-Real-IP $remote_addr;  # Add client IP header
    }
```

**Path-Based Routing:**

- `/app1/` → routes to app1 container
- `/app2/` → routes to app2 container
- `/app3/` → routes to app3 container
- `/internal/` → routes to nginx_south for internal APIs

**Header Management:**

- `Host`: Preserves original hostname for backend services
- `X-Real-IP`: Adds client IP for logging and security

### File: `nginx/south.conf` (Internal Proxy)

#### Internal Service Routing

```nginx
upstream mysql_up {
    server mysql:3306;  # Direct MySQL connection (demonstration)
}

server {
    listen 80;
    server_name south.local;    # Internal hostname

    location /mysql-proxy/ {
        return 200 "mysql proxy placeholder\n";  # Placeholder for DB proxy
    }

    location /health/ {
        return 200 "ok\n";      # Health check endpoint
    }
}
```

**Design Purpose:**

- Internal API gateway for service-to-service communication
- Health check endpoints for monitoring
- Future database proxy capabilities

---

## Database Configuration

### File: `mysql/my.cnf`

```ini
[mysqld]
innodb_buffer_pool_size=128M    # Memory allocation for InnoDB engine
max_connections=200             # Maximum concurrent connections
```

#### Configuration Analysis

**InnoDB Buffer Pool:**

- Default: 128MB (suitable for development)
- Production: Should be 70-80% of available RAM
- Purpose: Caches data and indexes in memory

**Connection Limits:**

- Default: 200 concurrent connections
- Prevents resource exhaustion
- Should be tuned based on application load

**Additional Production Settings:**

```ini
# Recommended additions for production
innodb_log_file_size=256M
innodb_flush_log_at_trx_commit=2
query_cache_type=1
query_cache_size=64M
slow_query_log=1
long_query_time=2
```

---

## DNS/DHCP Configuration

### File: `dnsmasq/dnsmasq.conf`

#### Basic Configuration

```bash
no-resolv           # Don't read /etc/resolv.conf
bind-interfaces     # Bind only to specified interfaces
domain-needed       # Never forward queries for plain names
expand-hosts        # Add domain to simple names
domain=localdomain  # Default domain for expansion
```

#### Static Host Mappings

```bash
address=/app1.local/127.0.0.1     # Map app1.local to loopback
address=/app2.local/127.0.0.1     # (Docker handles actual routing)
address=/app3.local/127.0.0.1
address=/mysql.local/127.0.0.1
```

**Why 127.0.0.1:**

- Docker's embedded DNS handles container name resolution
- These entries provide .local domain aliases
- Actual routing happens via Docker's network stack

#### DHCP Configuration

```bash
dhcp-range=192.168.77.50,192.168.77.150,12h
```

**DHCP Settings:**

- Range: 192.168.77.50 to 192.168.77.150
- Lease time: 12 hours
- Network: Demonstration subnet (isolated from host)

---

## NTP Configuration

### File: `ntp/chrony.conf`

```bash
pool pool.ntp.org iburst        # Use public NTP pool with rapid sync
allow 192.168.77.0/24          # Allow time queries from internal network
local stratum 10               # Act as local time source if isolated
driftfile /var/lib/chrony/drift # Store clock drift compensation
```

#### Configuration Analysis

**Pool Configuration:**

- `pool.ntp.org`: Public NTP pool for time source
- `iburst`: Rapid initial synchronization
- Production should use organization's NTP servers

**Network Access:**

- `allow 192.168.77.0/24`: Permits time queries from containers
- Matches dnsmasq DHCP range

**Drift Compensation:**

- `driftfile`: Stores clock drift measurements
- Improves accuracy over time
- Persisted via volume mount

**Production Considerations:**

```bash
# Additional production settings
server ntp1.company.com iburst
server ntp2.company.com iburst
makestep 1.0 3
rtcsync
```

---

## Build Configuration

### File: `builder/Dockerfile`

```dockerfile
FROM alpine:3.18                    # Minimal base image
RUN apk add --no-cache git openssh-client bash curl  # Essential tools
WORKDIR /builder                    # Set working directory
COPY build-and-deploy.sh /builder/build-and-deploy.sh
RUN chmod +x /builder/build-and-deploy.sh
ENTRYPOINT ["/builder/build-and-deploy.sh"]
```

#### Tool Selection

- `git`: Source code management
- `openssh-client`: SSH operations with agent forwarding
- `bash`: Advanced shell scripting
- `curl`: HTTP operations and health checks

### File: `builder/build-and-deploy.sh`

```bash
#!/bin/sh
set -e                              # Exit on any error
echo "[builder] starting build-and-deploy.sh"

# Generate application-specific content
cat > /app1_dist/index.html <<'EOF'
<!doctype html><html><body><h1>App1 - built by builder</h1></body></html>
EOF
```

#### Build Process

1. **Error Handling**: `set -e` ensures script stops on first error
2. **Content Generation**: Creates unique content for each application
3. **Volume Deployment**: Writes directly to shared volumes
4. **Verification**: Could include testing and validation steps

**Production Enhancements:**

```bash
# Additional build steps for production
git clone $REPO_URL /tmp/source
cd /tmp/source
npm install
npm run build
npm test
cp -r dist/* /app1_dist/
```

---

## Security Configuration

### File: `iptables/iptables.sh`

```bash
#!/bin/sh
echo "[iptables] applying sample iptables rules"

# Flush existing rules
iptables -F                         # Flush filter table
iptables -t nat -F                  # Flush NAT table
iptables -t mangle -F               # Flush mangle table

# Network segmentation
iptables -A FORWARD -s 192.168.100.0/24 -d 192.168.200.0/24 -j DROP

# Connection tracking
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Docker integration
iptables -A INPUT -i docker0 -j ACCEPT
```

#### Rule Analysis

**Table Flushing:**

- Ensures clean state before applying rules
- Prevents conflicts with existing rules

**Network Segmentation:**

- Demonstrates OT to IT network blocking
- Example subnets: 192.168.100.0/24 (OT) to 192.168.200.0/24 (IT)

**Connection Tracking:**

- Allows established connections to continue
- Blocks new inbound connections (default policy)

**Docker Integration:**

- Permits Docker bridge traffic
- Required for container communication

**Production Security:**

```bash
# Enhanced production rules
iptables -A INPUT -p tcp --dport 8080 -m limit --limit 25/minute -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -j DROP
```

---

## Environment Configuration

### File: `.env.example` / `.env`

```bash
# Database Configuration
MYSQL_ROOT_PASSWORD=replace_with_root_password
MYSQL_DATABASE=exampledb
MYSQL_USER=exampleuser
MYSQL_PASSWORD=examplepass
```

#### Security Considerations

**Password Requirements:**

- Root password: High complexity, unique
- User password: Application-specific, rotated regularly
- Production: Use secrets management (Vault, etc.)

**Database Naming:**

- Descriptive database names
- Environment-specific naming (dev, staging, prod)

```bash
# Network Configuration (dnsmasq)
DHCP_RANGE_START=192.168.77.50
DHCP_RANGE_END=192.168.77.150
DHCP_NETMASK=255.255.255.0
DNS_DOMAIN=localdomain
```

#### Network Planning

**DHCP Range:**

- Size: 101 IP addresses (sufficient for development)
- Isolation: Separate from host network
- Production: Plan for scalability

**Domain Strategy:**

- `.localdomain`: Clear separation from production domains
- `.local`: Alternative for mDNS compatibility
- Production: Use organization's domain structure

---

## Configuration Best Practices

### 1. Security

- Never commit `.env` files to version control
- Use read-only mounts for configuration files
- Implement least privilege access

### 2. Maintainability

- Comment all configuration files extensively
- Use environment variables for environment-specific values
- Version control all configuration templates

### 3. Monitoring

- Include health checks in all service definitions
- Configure appropriate timeouts and retry logic
- Implement structured logging

### 4. Performance

- Tune database settings for expected workload
- Configure nginx worker processes appropriately
- Use appropriate volume drivers for storage performance

### 5. Scalability

- Design for horizontal scaling from the beginning
- Use upstream definitions for load balancing
- Plan network architecture for growth

This comprehensive configuration analysis provides the foundation for understanding, maintaining, and extending the ChronoSync Infrastructure across different environments and use cases.
