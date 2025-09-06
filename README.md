# ChronoSync Infrastructure - Local Testing Environment

This repository contains a complete local, testable implementation of infrastructure for testing with Docker Compose:

- 1 x MySQL container (persistent data)
- 3 x application containers (each running nginx)
- 1 x north nginx (external-facing reverse proxy)
- 1 x south nginx (internal routing)
- dnsmasq providing DHCP + DNS
- NTP service (chrony)
- Discardable builder container for building apps (supports SSH-agent forwarding)
- iptables setup script (host-mode container, optional)
- Terraform skeleton in `/terraform` for later HCI deployment

## Architecture

The infrastructure implements a segmented network topology with:

- **IT Network**: External-facing services and management
- **OT Network**: Internal operational technology services
- **Internal Network**: Service-to-service communication

```
[Host:8080] -> [nginx_north] -> [app1|app2|app3]
                    |
                    v
               [nginx_south] -> [mysql]
                    |
                    v
              [dnsmasq] [ntp]
```

## Quick Start (Local)

1. **Copy and edit environment file**

   ```bash
   cp .env.example .env
   # Edit .env with your MySQL credentials
   ```

2. **Start all services**

   ```bash
   docker compose up --build
   ```

3. **Test the applications via north nginx**

   ```bash
   curl http://localhost:8080/app1/
   curl http://localhost:8080/app2/
   curl http://localhost:8080/app3/
   ```

4. **Test internal routing**

   ```bash
   curl http://localhost:8080/internal/health/
   ```

5. **Test DNS resolution**
   ```bash
   docker exec -it dnsmasq nslookup app1.local
   docker exec -it dnsmasq nslookup mysql.local
   ```

## Using the Builder (SSH-Agent Forwarding)

The builder container can clone private Git repositories and build artifacts using SSH-agent forwarding.

### On Linux/macOS:

```bash
# Ensure SSH-agent is running and your key is added
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# Start with SSH forwarding
SSH_AUTH_SOCK=$SSH_AUTH_SOCK docker compose up --build builder

# Or use the helper script
./scripts/start-local.sh
```

### On Windows (PowerShell):

```powershell
# Use the Windows helper script
.\scripts\start-local.bat
```

## Services Overview

### Core Application Services

- **app1, app2, app3**: Nginx containers serving static content or built artifacts
- **mysql**: MySQL 8.0 with persistent storage and health checks
- **nginx_north**: External reverse proxy (exposed on host:8080)
- **nginx_south**: Internal service mesh proxy

### Infrastructure Services

- **dnsmasq**: DHCP + DNS server for container name resolution
- **ntp**: Chrony NTP server for time synchronization
- **builder**: Temporary container for building and deploying artifacts
- **iptables-setup**: Host firewall configuration (optional)

### Network Topology

- **internal_net**: Private bridge network for service communication
- **it_net**: IT network bridge for management services

## Environment Configuration

Copy `.env.example` to `.env` and configure:

```bash
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_DATABASE=your_database_name
MYSQL_USER=your_username
MYSQL_PASSWORD=your_password

# DNS/DHCP settings
DHCP_RANGE_START=192.168.77.50
DHCP_RANGE_END=192.168.77.150
DHCP_NETMASK=255.255.255.0
DNS_DOMAIN=localdomain
```

## Security Considerations

### Network Segmentation

- Applications run on isolated Docker networks
- iptables rules demonstrate OT/IT network segmentation
- North nginx provides controlled external access

### Data Persistence

- All persistent data uses named Docker volumes
- MySQL data survives container restarts
- Builder cache improves build performance

### SSH Security

- SSH-agent forwarding allows secure Git operations
- Private keys never stored in containers
- Builder container is discardable after use

## Monitoring and Health Checks

All critical services include health checks:

- **MySQL**: Connection and ping tests
- **Nginx**: Process monitoring
- **Apps**: HTTP endpoint validation

View service status:

```bash
docker compose ps
docker compose logs [service_name]
```

## Development Workflow

1. **Local Development**

   ```bash
   # Start infrastructure
   docker compose up --build

   # Build and deploy applications
   docker compose up --build builder

   # Test applications
   curl http://localhost:8080/app1/
   ```

2. **Making Changes**

   ```bash
   # Rebuild specific service
   docker compose up --build app1

   # View logs
   docker compose logs -f nginx_north
   ```

3. **Cleanup**

   ```bash
   # Stop all services
   docker compose down

   # Remove volumes (WARNING: deletes data)
   docker compose down -v
   ```

## Testing Commands

### Application Testing

```bash
# Test all applications
for app in app1 app2 app3; do
  echo "Testing $app..."
  curl -s http://localhost:8080/$app/ | grep -q "$app" && echo "✓ $app OK" || echo "✗ $app FAILED"
done

# Test internal routing
curl http://localhost:8080/internal/health/
```

### DNS Testing

```bash
# Test DNS resolution
docker exec dnsmasq nslookup app1.local
docker exec dnsmasq nslookup mysql.local
docker exec dnsmasq nslookup nginx-north.local
```

### Network Testing

```bash
# Check network connectivity
docker exec app1 ping -c 3 mysql
docker exec nginx_north ping -c 3 app2
```

## Terraform Deployment (HCI)

The `/terraform` directory contains a provider-agnostic skeleton for HCI deployment.

### Setup

1. Navigate to terraform directory:

   ```bash
   cd terraform
   ```

2. Configure your HCI provider in `main.tf`
3. Initialize Terraform:

   ```bash
   terraform init
   ```

4. Plan deployment:

   ```bash
   terraform plan
   ```

5. Apply configuration:
   ```bash
   terraform apply
   ```

See `terraform/README-terraform.md` for provider-specific instructions.

## Troubleshooting

### Common Issues

**Container fails to start:**

```bash
# Check logs
docker compose logs [service_name]

# Check container status
docker compose ps
```

**Port conflicts:**

```bash
# Check what's using port 8080
netstat -tulpn | grep 8080

# Use different ports in docker-compose.yml
```

**MySQL connection issues:**

```bash
# Verify environment variables
docker compose config

# Check MySQL logs
docker compose logs mysql
```

**DNS resolution problems:**

```bash
# Restart dnsmasq
docker compose restart dnsmasq

# Check dnsmasq configuration
docker exec dnsmasq cat /etc/dnsmasq.conf
```

### Performance Tuning

**MySQL Optimization:**

- Edit `mysql/my.cnf` for your workload
- Adjust `innodb_buffer_pool_size` based on available RAM
- Monitor with `docker stats mysql_db`

**Nginx Optimization:**

- Configure worker processes in nginx configs
- Enable gzip compression for static content
- Implement caching for API responses

## Production Deployment Notes

### Security Hardening

- [ ] Replace default passwords in `.env`
- [ ] Enable TLS/SSL termination in nginx_north
- [ ] Implement proper certificate management
- [ ] Configure firewall rules for production networks
- [ ] Use secrets management instead of environment variables

### High Availability

- [ ] Deploy MySQL in cluster configuration
- [ ] Implement nginx load balancing
- [ ] Add health check endpoints for all services
- [ ] Configure log aggregation and monitoring

### Backup and Recovery

- [ ] Implement automated MySQL backups
- [ ] Test restore procedures
- [ ] Document recovery processes
- [ ] Configure off-site backup storage

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `docker compose up --build`
5. Submit a pull request

## License

See `LICENSE` file for details.

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review Docker Compose logs
3. Open an issue with full error details and environment information
