#!/bin/bash
# Quick setup verification script

echo "🔍 ChronoSync Infrastructure Setup Verification"
echo "================================================"

# Check if all required files exist
required_files=(
    "docker-compose.yml"
    ".env.example"
    "app/Dockerfile"
    "app/static/index.html"
    "nginx/north.conf"
    "nginx/south.conf"
    "mysql/my.cnf"
    "dnsmasq/dnsmasq.conf"
    "ntp/chrony.conf"
    "builder/Dockerfile"
    "builder/build-and-deploy.sh"
    "iptables/iptables.sh"
    "terraform/main.tf"
    "terraform/variables.tf"
    "terraform/README-terraform.md"
)

echo "✅ Checking required files..."
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
    fi
done

# Check directories
required_dirs=(
    "app/static"
    "nginx"
    "mysql"
    "dnsmasq"
    "ntp"
    "builder"
    "iptables"
    "terraform"
    "scripts"
    ".github/workflows"
)

echo ""
echo "📁 Checking required directories..."
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir/"
    else
        echo "  ✗ $dir/ (MISSING)"
    fi
done

echo ""
echo "🔧 Next Steps:"
echo "1. Copy .env.example to .env: cp .env.example .env"
echo "2. Edit .env with your MySQL credentials"
echo "3. Start infrastructure: docker compose up --build"
echo "4. Run tests: ./scripts/test-infrastructure.sh"
echo ""
echo "📖 For detailed instructions, see README.md"
