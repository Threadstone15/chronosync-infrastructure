# ChronoSync Infrastructure - Quick Reference Guide

## 🚀 Quick Commands

### Essential Operations

```bash
# Start everything
make start

# Stop everything
make stop

# View logs
make logs

# Run tests
make test

# Clean everything (WARNING: removes data)
make clean
```

### Individual Service Management

```bash
# Restart specific service
docker compose restart app1

# View specific logs
docker compose logs -f nginx_north

# Check service health
docker compose ps
```

## 📊 Service Endpoints

| Service     | Internal Address | External Address     | Purpose                |
| ----------- | ---------------- | -------------------- | ---------------------- |
| nginx_north | nginx_north:80   | localhost:8080       | External reverse proxy |
| nginx_south | nginx_south:80   | N/A                  | Internal service mesh  |
| app1        | app1:80          | localhost:8080/app1/ | Application 1          |
| app2        | app2:80          | localhost:8080/app2/ | Application 2          |
| app3        | app3:80          | localhost:8080/app3/ | Application 3          |
| mysql       | mysql:3306       | N/A                  | Database server        |
| dnsmasq     | dnsmasq:53       | N/A                  | DNS/DHCP server        |
| ntp         | ntp:123          | N/A                  | Time synchronization   |

## 🔧 Configuration Files Quick Reference

### Core Configuration

- `docker-compose.yml` - Main orchestration
- `.env` - Environment variables (create from `.env.example`)
- `Makefile` - Common operations

### Service Configurations

- `nginx/north.conf` - External proxy routing
- `nginx/south.conf` - Internal proxy routing
- `mysql/my.cnf` - Database tuning
- `dnsmasq/dnsmasq.conf` - DNS/DHCP setup
- `ntp/chrony.conf` - Time server config

### Application Files

- `app/Dockerfile` - Application container
- `app/static/index.html` - Default content
- `builder/build-and-deploy.sh` - Build automation

## 🌐 Network Architecture

```
External (Host:8080) → it_net → nginx_north → Apps
                              ↘
                        internal_net → nginx_south → mysql
                                    ↘
                                   dnsmasq, ntp
```

### Networks

- **it_net**: External-facing services (nginx_north, apps)
- **internal_net**: All services for inter-communication

### DNS Names (via dnsmasq)

- `app1.local`, `app2.local`, `app3.local`
- `mysql.local`, `nginx-north.local`, `nginx-south.local`

## 🔐 Security Notes

### Access Control

- Only nginx_north exposed to host (port 8080)
- All other services internal-only
- SSH agent forwarding for builder

### Data Persistence

- `mysql_data` - Database files
- `app1_data`, `app2_data`, `app3_data` - Application content
- `dnsmasq_data`, `ntp_data`, `builder_cache` - Service data

## 🧪 Testing Commands

### HTTP Tests

```bash
# Test all applications
curl http://localhost:8080/app1/
curl http://localhost:8080/app2/
curl http://localhost:8080/app3/
curl http://localhost:8080/internal/health/
```

### DNS Tests

```bash
# Test service discovery
docker exec dnsmasq nslookup app1.local
docker exec dnsmasq nslookup mysql.local
```

### Network Tests

```bash
# Test inter-service connectivity
docker exec app1 ping mysql_db
docker exec nginx_north ping app2
```

## 🛠️ Troubleshooting Quick Fixes

### Container Won't Start

```bash
docker compose logs <service_name>
docker compose ps
```

### Port Conflicts

```bash
netstat -tulpn | grep 8080
# Edit docker-compose.yml ports section
```

### Permission Issues

```bash
# Fix script permissions
chmod +x scripts/*.sh
```

### Database Issues

```bash
# Check MySQL logs
docker compose logs mysql

# Test connection
docker exec mysql_db mysqladmin ping
```

## 📝 Environment Variables

### Required (.env file)

```bash
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_DATABASE=your_database_name
MYSQL_USER=your_username
MYSQL_PASSWORD=your_password
```

### Optional

```bash
DHCP_RANGE_START=192.168.77.50
DHCP_RANGE_END=192.168.77.150
DHCP_NETMASK=255.255.255.0
DNS_DOMAIN=localdomain
```

## 🏗️ Builder Usage

### With SSH Agent (Linux/macOS)

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
SSH_AUTH_SOCK=$SSH_AUTH_SOCK docker compose up --build builder
```

### With Scripts

```bash
./scripts/start-local.sh      # Linux/macOS
.\scripts\start-local.bat     # Windows
```

## 📊 Health Checks

### Service Status

```bash
# Overall status
docker compose ps

# Health details
docker inspect mysql_db | grep -A 10 '"Health"'
```

### Service Dependencies

- nginx_north depends on: app1, app2, app3
- nginx_south depends on: mysql
- All services connect to: internal_net

## 🔄 Volume Management

### Backup Volumes

```bash
# Backup MySQL data
docker run --rm -v mysql_data:/data -v $(pwd):/backup alpine tar czf /backup/mysql_backup.tar.gz /data

# Backup application data
docker run --rm -v app1_data:/data -v $(pwd):/backup alpine tar czf /backup/app1_backup.tar.gz /data
```

### Reset Environment

```bash
# DANGER: This removes all data
docker compose down -v
docker volume prune -f
```

## 📚 File Structure Reference

```
chronosync-infrastructure/
├── app/                     # Application containers
├── builder/                 # Build automation
├── nginx/                   # Proxy configurations
├── mysql/                   # Database config
├── dnsmasq/                 # DNS/DHCP config
├── ntp/                     # Time server config
├── iptables/                # Firewall rules
├── scripts/                 # Helper scripts
├── terraform/               # HCI deployment
├── .github/workflows/       # CI/CD
├── docker-compose.yml       # Main orchestration
├── .env.example             # Environment template
├── Makefile                 # Common operations
└── README.md               # Main documentation
```

## 🎯 Common Use Cases

### Development Workflow

1. `make setup` - Initial setup
2. `make start` - Start all services
3. Edit code/configs
4. `make restart` - Apply changes
5. `make test` - Verify functionality

### Production Preparation

1. Edit `.env` with production values
2. Review security configurations
3. Test with `make test`
4. Deploy with Terraform (see `terraform/`)

### Troubleshooting Workflow

1. `make status` - Check service status
2. `make logs` - Review logs
3. Test individual components
4. Check network connectivity
5. Verify configurations
