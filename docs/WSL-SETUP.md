# ChronoSync Infrastructure on WSL2

## Why WSL2 is Excellent for This Infrastructure

WSL2 provides near-native Linux experience with these advantages:

### ✅ **What Works Perfectly:**

- **Native Docker Engine**: True Linux containers, not Docker Desktop
- **MacVlan Support**: Full layer-2 networking capabilities
- **NTP Service**: Proper system time access with privileges
- **SSH Agent**: Native SSH functionality
- **iptables**: Full Linux networking stack
- **Performance**: Native Linux performance for containers

### ✅ **WSL2 Advantages:**

- **Hybrid Access**: Windows tools + Linux containers
- **File System Integration**: Access files from both environments
- **Network Bridge**: WSL2 acts as a bridge to Windows network
- **Resource Sharing**: Shared memory and CPU with Windows

## Setup Instructions

### 1. Install Docker in WSL2 (Not Docker Desktop)

```bash
# Update WSL2 Ubuntu
sudo apt update && sudo apt upgrade -y

# Install Docker CE (Community Edition)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker service
sudo service docker start

# Enable Docker to start automatically
echo "sudo service docker start" >> ~/.bashrc
```

### 2. Install Docker Compose

```bash
# Install Docker Compose
sudo apt install docker-compose-plugin

# Verify installation
docker compose version
```

### 3. Clone and Setup Infrastructure

```bash
# Clone repository to WSL2 filesystem (important!)
cd ~
git clone /mnt/c/Users/ASUS/Desktop/chronosync-infrastructure
cd chronosync-infrastructure

# Or clone fresh from GitHub
# git clone https://github.com/Threadstone15/chronosync-infrastructure.git
# cd chronosync-infrastructure

# Copy environment file
cp .env.example .env

# Edit with nano or vim
nano .env
```

### 4. Configure MacVlan for WSL2

```bash
# Check WSL2 network interface
ip addr show

# Setup MacVlan (this script will auto-detect)
chmod +x scripts/setup-macvlan.sh
./scripts/setup-macvlan.sh

# Or manually configure in .env:
# MACVLAN_PARENT_INTERFACE=eth0
# MACVLAN_SUBNET=192.168.1.0/24
# MACVLAN_GATEWAY=192.168.1.1
# MACVLAN_IP_RANGE=192.168.1.96/28
```

### 5. Start Infrastructure

```bash
# Start all services
docker compose up --build -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

## WSL2-Specific Features

### MacVlan Networking in WSL2

WSL2's network adapter supports MacVlan, enabling:

- **Direct DHCP service** to your Windows network
- **Layer-2 network integration**
- **Real network device simulation**

```bash
# Test MacVlan functionality
./scripts/test-macvlan.sh

# Check container IPs on your network
docker network inspect chronosync-infrastructure_macvlan_net
```

### NTP Service in WSL2

Unlike Docker Desktop, WSL2 allows proper NTP functionality:

```bash
# Check NTP service
docker compose logs ntp

# Test time synchronization
docker compose exec ntp chronyc sources
```

### SSH Agent Forwarding

WSL2 provides native SSH agent support:

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add your SSH key
ssh-add ~/.ssh/id_rsa

# Start with SSH forwarding
./scripts/start-local.sh
```

## Network Access from Windows

### Access Applications from Windows

The infrastructure will be accessible from Windows:

```powershell
# From Windows PowerShell/Command Prompt
curl http://localhost:8080/app1/
curl http://localhost:8080/app2/
curl http://localhost:8080/app3/

# Or open in browser
start http://localhost:8080
```

### WSL2 IP Discovery

```bash
# Get WSL2 IP address
hostname -I

# Access from Windows using WSL2 IP
# http://[wsl2-ip]:8080
```

## Performance Comparison

| Feature               | WSL2            | Docker Desktop   | Native Linux    |
| --------------------- | --------------- | ---------------- | --------------- |
| Container Performance | ✅ Near-native  | ⚠️ VM overhead   | ✅ Native       |
| MacVlan Support       | ✅ Full support | ❌ Not supported | ✅ Full support |
| NTP Service           | ✅ Works        | ❌ Fails         | ✅ Works        |
| SSH Agent             | ✅ Native       | ⚠️ Complex       | ✅ Native       |
| File I/O              | ✅ Fast         | ⚠️ Slower        | ✅ Fastest      |
| Network Integration   | ✅ Bridge mode  | ⚠️ NAT only      | ✅ Direct       |

## Troubleshooting WSL2

### Docker Service Issues

```bash
# If Docker fails to start
sudo service docker status
sudo service docker restart

# Check Docker daemon
sudo dockerd --debug
```

### Network Issues

```bash
# Reset WSL2 network
# From Windows PowerShell (as Administrator):
# wsl --shutdown
# wsl

# Check WSL2 networking
ip route show
cat /etc/resolv.conf
```

### File Permission Issues

```bash
# If permission issues with mounted Windows files
# Clone to WSL2 filesystem instead
cp -r /mnt/c/Users/ASUS/Desktop/chronosync-infrastructure ~/
cd ~/chronosync-infrastructure
```

## Best Practices for WSL2

1. **Use WSL2 Filesystem**: Store project in `~/` not `/mnt/c/`
2. **Resource Limits**: Configure `.wslconfig` if needed
3. **Auto-start Docker**: Add to `.bashrc` or use systemd
4. **Network Configuration**: Use WSL2 bridge for MacVlan
5. **SSH Keys**: Generate keys in WSL2, not Windows

## Migration from Docker Desktop

If migrating from Docker Desktop:

```bash
# Stop Docker Desktop
# From Windows: Docker Desktop -> Quit

# Start in WSL2
wsl
sudo service docker start
cd ~/chronosync-infrastructure
docker compose up --build -d
```
