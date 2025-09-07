#!/bin/bash

# ChronoSync Infrastructure - WSL2 Quick Setup
# Run this script inside WSL2 Ubuntu

set -e

echo "🚀 Setting up ChronoSync Infrastructure on WSL2..."

# Check if running in WSL2
if ! grep -q microsoft /proc/version; then
    echo "❌ This script must be run inside WSL2"
    exit 1
fi

echo "✅ Running in WSL2"

# Start Docker daemon if not running
if ! docker info >/dev/null 2>&1; then
    echo "🐳 Starting Docker daemon..."
    sudo dockerd --detach >/dev/null 2>&1 || true
    sleep 5
fi

# Verify Docker is working
if docker info >/dev/null 2>&1; then
    echo "✅ Docker is running"
else
    echo "❌ Docker failed to start. Try: sudo dockerd --detach"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "📦 Installing docker-compose..."
    sudo apt update
    sudo apt install -y docker-compose
fi

echo "✅ Docker Compose available"

# Copy files to WSL filesystem if needed
WSL_PROJECT_DIR="$HOME/chronosync-infrastructure"

if [ ! -d "$WSL_PROJECT_DIR" ]; then
    echo "📂 Copying project to WSL filesystem..."
    cp -r /mnt/c/Users/ASUS/Desktop/chronosync-infrastructure "$WSL_PROJECT_DIR"
    cd "$WSL_PROJECT_DIR"
    
    # Fix permissions
    chmod +x scripts/*.sh
    chmod +x scripts/*.bat
    
    echo "✅ Project copied to $WSL_PROJECT_DIR"
else
    echo "✅ Project already exists in WSL filesystem"
    cd "$WSL_PROJECT_DIR"
fi

# Setup environment file
if [ ! -f .env ]; then
    echo "⚙️ Setting up environment file..."
    cp .env.example .env
    echo "✅ Environment file created - edit .env as needed"
fi

# Auto-detect network interface for MacVlan
echo "🌐 Detecting network interface..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "✅ Detected interface: $INTERFACE"

# Check if MacVlan variables need to be set
if ! grep -q "MACVLAN_PARENT_INTERFACE=$INTERFACE" .env; then
    echo "🔧 Configuring MacVlan settings..."
    sed -i "s/MACVLAN_PARENT_INTERFACE=.*/MACVLAN_PARENT_INTERFACE=$INTERFACE/" .env
    echo "✅ MacVlan configured for interface: $INTERFACE"
fi

echo ""
echo "🎉 WSL2 setup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Review and edit .env file if needed:"
echo "      nano .env"
echo ""
echo "   2. Start the infrastructure:"
echo "      docker-compose up --build -d"
echo ""
echo "   3. Check status:"
echo "      docker-compose ps"
echo ""
echo "   4. Access from Windows browser:"
echo "      http://localhost:8080"
echo ""
echo "   5. Test MacVlan functionality:"
echo "      ./scripts/test-macvlan.sh"
echo ""

# Show current directory and files
echo "📁 Current location: $(pwd)"
echo "📂 Available files:"
ls -la

echo ""
echo "🚀 Ready to launch! Run: docker-compose up --build -d"
