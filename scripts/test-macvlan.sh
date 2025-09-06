#!/bin/bash
# MacVlan Network Testing Script
# Tests MacVlan connectivity and DHCP functionality

set -e

echo "🧪 MacVlan Network Testing Suite"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Test 1: Check if MacVlan network exists
print_info "Testing MacVlan network configuration..."

if docker network ls | grep -q "macvlan_net"; then
    print_status 0 "MacVlan network exists"
    
    # Get network details
    echo "MacVlan network details:"
    docker network inspect chronosync-infrastructure_macvlan_net | jq -r '.[0].IPAM.Config[0]' 2>/dev/null || docker network inspect chronosync-infrastructure_macvlan_net
else
    print_status 1 "MacVlan network not found"
    echo "Run 'docker compose up -d' to create the network"
    exit 1
fi

echo ""

# Test 2: Check dnsmasq container on MacVlan
print_info "Testing dnsmasq MacVlan connectivity..."

if docker ps | grep -q "dnsmasq"; then
    print_status 0 "dnsmasq container is running"
    
    # Check network interfaces in dnsmasq container
    echo "dnsmasq network interfaces:"
    docker exec dnsmasq ip addr show | grep -E "inet |eth"
    
    # Check if dnsmasq is bound to MacVlan interface
    MACVLAN_IP=$(docker exec dnsmasq ip addr show | grep "inet " | grep -v "127.0.0.1" | tail -1 | awk '{print $2}' | cut -d'/' -f1)
    if [ ! -z "$MACVLAN_IP" ]; then
        print_status 0 "dnsmasq has MacVlan IP: $MACVLAN_IP"
    else
        print_warning "dnsmasq may not have MacVlan IP assigned"
    fi
else
    print_status 1 "dnsmasq container not running"
    echo "Start it with: docker compose up -d dnsmasq"
fi

echo ""

# Test 3: Check DHCP functionality
print_info "Testing DHCP functionality..."

if docker ps | grep -q "dnsmasq"; then
    # Check dnsmasq DHCP logs
    echo "Recent DHCP activity:"
    docker logs dnsmasq 2>&1 | grep -i dhcp | tail -5 || echo "No DHCP logs found"
    
    # Test DHCP discover (if dhclient is available)
    if command -v dhclient &> /dev/null; then
        print_info "Testing DHCP discover on MacVlan network..."
        # This is a more advanced test that would require careful setup
        print_warning "DHCP discover test requires careful network configuration"
    else
        print_info "dhclient not available for DHCP testing"
    fi
else
    print_warning "Cannot test DHCP - dnsmasq not running"
fi

echo ""

# Test 4: Test app1 MacVlan connectivity
print_info "Testing app1 MacVlan connectivity..."

if docker ps | grep -q "app1"; then
    print_status 0 "app1 container is running"
    
    # Check if app1 has MacVlan interface
    APP1_MACVLAN_IP=$(docker exec app1 ip addr show | grep "inet " | grep -v "127.0.0.1" | grep -v "172\." | awk '{print $2}' | cut -d'/' -f1 | head -1)
    
    if [ ! -z "$APP1_MACVLAN_IP" ]; then
        print_status 0 "app1 has potential MacVlan IP: $APP1_MACVLAN_IP"
        
        # Test connectivity from app1 to external network
        if docker exec app1 ping -c 2 8.8.8.8 &>/dev/null; then
            print_status 0 "app1 can reach external network via MacVlan"
        else
            print_warning "app1 cannot reach external network"
        fi
    else
        print_warning "app1 may not have MacVlan IP"
    fi
    
    # Show all network interfaces in app1
    echo "app1 network interfaces:"
    docker exec app1 ip addr show | grep -E "inet |eth"
    
else
    print_status 1 "app1 container not running"
fi

echo ""

# Test 5: Network connectivity between MacVlan and bridge networks
print_info "Testing inter-network connectivity..."

if docker ps | grep -q "app1" && docker ps | grep -q "mysql_db"; then
    # Test connectivity from MacVlan app1 to bridge network mysql
    if docker exec app1 ping -c 2 mysql_db &>/dev/null; then
        print_status 0 "MacVlan app1 can reach bridge network mysql"
    else
        print_warning "MacVlan app1 cannot reach bridge network mysql"
        echo "This is expected if networks are isolated"
    fi
    
    # Test DNS resolution
    if docker exec app1 nslookup mysql.local &>/dev/null; then
        print_status 0 "DNS resolution working from MacVlan network"
    else
        print_warning "DNS resolution may not work from MacVlan network"
    fi
fi

echo ""

# Test 6: External network access from host
print_info "Testing external access to MacVlan services..."

if [ ! -z "$MACVLAN_IP" ]; then
    # Try to ping MacVlan dnsmasq from host
    if ping -c 2 "$MACVLAN_IP" &>/dev/null; then
        print_status 0 "Host can reach MacVlan dnsmasq at $MACVLAN_IP"
    else
        print_warning "Host cannot reach MacVlan dnsmasq at $MACVLAN_IP"
        echo "This may be due to MacVlan limitations or network configuration"
    fi
    
    # Try to query DNS from host
    if nslookup app1.local "$MACVLAN_IP" &>/dev/null; then
        print_status 0 "DNS query to MacVlan dnsmasq successful"
    else
        print_warning "DNS query to MacVlan dnsmasq failed"
    fi
fi

echo ""

# Test 7: Check Docker network driver
print_info "Verifying MacVlan network driver..."

NETWORK_DRIVER=$(docker network inspect chronosync-infrastructure_macvlan_net | jq -r '.[0].Driver' 2>/dev/null || echo "unknown")
if [ "$NETWORK_DRIVER" = "macvlan" ]; then
    print_status 0 "Network is using macvlan driver"
else
    print_status 1 "Network is not using macvlan driver (found: $NETWORK_DRIVER)"
fi

# Check parent interface
PARENT_INTERFACE=$(docker network inspect chronosync-infrastructure_macvlan_net | jq -r '.[0].Options.parent' 2>/dev/null || echo "unknown")
if [ "$PARENT_INTERFACE" != "unknown" ] && [ "$PARENT_INTERFACE" != "null" ]; then
    print_status 0 "Parent interface: $PARENT_INTERFACE"
    
    # Check if parent interface exists on host
    if ip link show "$PARENT_INTERFACE" &>/dev/null; then
        print_status 0 "Parent interface $PARENT_INTERFACE exists on host"
    else
        print_status 1 "Parent interface $PARENT_INTERFACE not found on host"
    fi
else
    print_warning "Parent interface not detected"
fi

echo ""

# Summary and recommendations
print_info "MacVlan Test Summary:"
echo "===================="

print_info "If MacVlan is working correctly, you should see:"
echo "1. ✓ dnsmasq with MacVlan IP address"
echo "2. ✓ app1 with MacVlan IP address"
echo "3. ✓ External network connectivity from containers"
echo "4. ✓ DNS resolution working"

echo ""
print_warning "Common MacVlan limitations:"
echo "- Host cannot reach MacVlan containers directly"
echo "- VM environments may have restrictions"
echo "- Some cloud providers block MacVlan traffic"
echo "- Docker Desktop on Windows/Mac has limited support"

echo ""
print_info "Troubleshooting tips:"
echo "1. Check parent interface configuration"
echo "2. Verify network subnet doesn't conflict"
echo "3. Ensure parent interface supports promiscuous mode"
echo "4. Check firewall rules on host"
echo "5. Consider using Linux environment for full support"

echo ""
print_info "For more details, check the logs:"
echo "  docker compose logs dnsmasq"
echo "  docker compose logs app1"
