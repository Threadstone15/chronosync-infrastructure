#!/bin/bash
# MacVlan Network Setup Script
# Detects network interface and configures MacVlan networking

set -e

echo "🔧 MacVlan Network Setup for ChronoSync Infrastructure"
echo "====================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root (needed for some network operations)
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root. Some operations may require elevated privileges."
fi

# Detect network interfaces
print_info "Detecting available network interfaces..."

# Get active network interfaces (excluding loopback)
INTERFACES=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | awk -F': ' '{print $2}' | cut -d'@' -f1)

echo "Available network interfaces:"
for iface in $INTERFACES; do
    # Get interface status
    STATUS=$(ip link show $iface | grep -o "state [A-Z]*" | awk '{print $2}')
    if [ "$STATUS" = "UP" ]; then
        echo -e "  ${GREEN}✓${NC} $iface (UP)"
    else
        echo -e "  ${YELLOW}⚠${NC} $iface ($STATUS)"
    fi
done

# Try to detect the main network interface
MAIN_INTERFACE=""

# Method 1: Check default route
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ ! -z "$DEFAULT_INTERFACE" ]; then
    MAIN_INTERFACE=$DEFAULT_INTERFACE
    print_status 0 "Detected main interface via default route: $MAIN_INTERFACE"
else
    print_warning "Could not detect main interface via default route"
fi

# Method 2: Check for active Ethernet interfaces
if [ -z "$MAIN_INTERFACE" ]; then
    ETH_INTERFACES=$(echo "$INTERFACES" | grep -E "^(eth|ens|enp)" | head -n1)
    if [ ! -z "$ETH_INTERFACES" ]; then
        MAIN_INTERFACE=$ETH_INTERFACES
        print_status 0 "Detected Ethernet interface: $MAIN_INTERFACE"
    fi
fi

# Method 3: Use first UP interface
if [ -z "$MAIN_INTERFACE" ]; then
    for iface in $INTERFACES; do
        STATUS=$(ip link show $iface | grep -o "state [A-Z]*" | awk '{print $2}')
        if [ "$STATUS" = "UP" ]; then
            MAIN_INTERFACE=$iface
            print_status 0 "Using first UP interface: $MAIN_INTERFACE"
            break
        fi
    done
fi

if [ -z "$MAIN_INTERFACE" ]; then
    print_status 1 "Could not detect suitable network interface"
    echo "Please manually specify the interface in .env file:"
    echo "MACVLAN_PARENT_INTERFACE=your_interface_name"
    exit 1
fi

# Get network information for the detected interface
print_info "Gathering network information for $MAIN_INTERFACE..."

# Get IP address and subnet
IP_INFO=$(ip addr show $MAIN_INTERFACE | grep "inet " | head -n1 | awk '{print $2}')
if [ ! -z "$IP_INFO" ]; then
    IP_ADDRESS=$(echo $IP_INFO | cut -d'/' -f1)
    SUBNET_MASK=$(echo $IP_INFO | cut -d'/' -f2)
    
    # Calculate network subnet
    NETWORK=$(ipcalc -n $IP_INFO 2>/dev/null | cut -d'=' -f2 || echo "")
    if [ -z "$NETWORK" ]; then
        # Fallback method for network calculation
        IFS='.' read -r i1 i2 i3 i4 <<< "$IP_ADDRESS"
        case $SUBNET_MASK in
            24) NETWORK="$i1.$i2.$i3.0/24" ;;
            16) NETWORK="$i1.$i2.0.0/16" ;;
            8) NETWORK="$i1.0.0.0/8" ;;
            *) NETWORK="$i1.$i2.$i3.0/24" ;; # Default assumption
        esac
    fi
    
    print_status 0 "Interface $MAIN_INTERFACE: $IP_ADDRESS/$SUBNET_MASK"
    print_status 0 "Detected network: $NETWORK"
else
    print_warning "Could not detect IP configuration for $MAIN_INTERFACE"
    NETWORK="192.168.1.0/24"  # Default fallback
fi

# Get gateway
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
if [ ! -z "$GATEWAY" ]; then
    print_status 0 "Detected gateway: $GATEWAY"
else
    print_warning "Could not detect gateway"
    GATEWAY="192.168.1.1"  # Default fallback
fi

# Generate MacVlan IP range (use a small subset to avoid conflicts)
if [ ! -z "$NETWORK" ]; then
    # Extract base network
    BASE_NETWORK=$(echo $NETWORK | cut -d'.' -f1-3)
    MACVLAN_IP_RANGE="$BASE_NETWORK.200/29"  # .200-.207 (8 IPs)
    print_status 0 "Generated MacVlan IP range: $MACVLAN_IP_RANGE"
else
    MACVLAN_IP_RANGE="192.168.1.200/29"
fi

# Create or update .env file
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    print_info "Creating .env file from .env.example..."
    cp .env.example .env
fi

print_info "Updating .env file with detected network configuration..."

# Update MacVlan settings in .env
sed -i.bak \
    -e "s/MACVLAN_PARENT_INTERFACE=.*/MACVLAN_PARENT_INTERFACE=$MAIN_INTERFACE/" \
    -e "s|MACVLAN_SUBNET=.*|MACVLAN_SUBNET=$NETWORK|" \
    -e "s/MACVLAN_GATEWAY=.*/MACVLAN_GATEWAY=$GATEWAY/" \
    -e "s|MACVLAN_IP_RANGE=.*|MACVLAN_IP_RANGE=$MACVLAN_IP_RANGE|" \
    "$ENV_FILE"

print_status 0 "Updated .env file with MacVlan configuration"

# Verify Docker network requirements
print_info "Verifying Docker MacVlan requirements..."

# Check if interface supports promiscuous mode
if ip link show $MAIN_INTERFACE | grep -q PROMISC; then
    print_status 0 "Interface $MAIN_INTERFACE supports promiscuous mode"
else
    print_warning "Interface $MAIN_INTERFACE may not support promiscuous mode"
    echo "  You may need to enable it: sudo ip link set $MAIN_INTERFACE promisc on"
fi

# Check for existing Docker networks
EXISTING_MACVLAN=$(docker network ls | grep macvlan || true)
if [ ! -z "$EXISTING_MACVLAN" ]; then
    print_warning "Existing MacVlan networks detected:"
    echo "$EXISTING_MACVLAN"
fi

echo ""
print_info "MacVlan configuration summary:"
echo "  Interface: $MAIN_INTERFACE"
echo "  Network: $NETWORK"
echo "  Gateway: $GATEWAY"
echo "  MacVlan Range: $MACVLAN_IP_RANGE"
echo ""

print_info "Next steps:"
echo "1. Review the generated .env file configuration"
echo "2. Ensure your network allows the MacVlan IP range"
echo "3. Start the infrastructure: docker compose up --build"
echo "4. Test MacVlan connectivity"

print_warning "Important notes:"
echo "- MacVlan containers will have direct network access"
echo "- Some host networks may block MacVlan traffic"
echo "- VM environments may have limited MacVlan support"
echo "- Windows Docker Desktop has limited MacVlan support"

echo ""
print_info "To test MacVlan setup:"
echo "  docker compose up -d dnsmasq"
echo "  docker exec dnsmasq ip addr show"
