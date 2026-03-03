#!/bin/bash

# Titanic HTB Lab - Quick Start Script

set -e

echo "========================================="
echo "  Titanic HTB Lab - Quick Start"
echo "========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check /etc/hosts
echo "📝 Checking /etc/hosts entries..."
if ! grep -q "titanic.htb" /etc/hosts; then
    echo "⚠️  DNS entries not found in /etc/hosts"
    echo ""
    echo "Please add the following to your /etc/hosts file:"
    echo ""
    echo "    127.0.0.1 titanic.htb dev.titanic.htb"
    echo ""
    echo "Run this command:"
    echo "    echo '127.0.0.1 titanic.htb dev.titanic.htb' | sudo tee -a /etc/hosts"
    echo ""
    read -p "Have you added the entries? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting. Please add the DNS entries first."
        exit 1
    fi
else
    echo "✅ DNS entries found"
fi

# Build containers
echo ""
echo "🔨 Building Docker containers..."
echo "   This may take 5-10 minutes on first run..."
echo ""
docker compose build

# Start containers
echo ""
echo "🚀 Starting containers..."
docker compose up -d

# Wait for services
echo ""
echo "⏳ Waiting for services to start..."
sleep 5

# Initialize Gitea users
echo ""
echo "🔧 Initializing Gitea..."
bash scripts/gitea-init-exec.sh

# Check status
echo ""
echo "📊 Container status:"
docker compose ps

# Display access information
echo ""
echo "========================================="
echo "  Lab is ready!"
echo "========================================="
echo ""
echo "🌐 Web Interfaces:"
echo "   • Main Site:  http://titanic.htb:8080"
echo "   • Gitea:      http://dev.titanic.htb:8080"
echo ""
echo "🔐 SSH Access:"
echo "   • Port: 2223"
echo "   • Command: ssh developer@localhost -p 2223"
echo "   • Password: 25282528"
echo ""
echo "📚 Documentation:"
echo "   • README:     ./README.md"
echo "   • Walkthrough: ./docs/WALKTHROUGH.md"
echo "   • Gitea Setup: ./docs/GITEA_SETUP.md"
echo ""
echo "⚠️  Note: Gitea needs ~30 seconds to fully initialize"
echo "   You can check logs with: docker compose logs -f gitea"
echo ""
echo "🎯 To stop the lab:"
echo "   docker compose down"
echo ""
echo "🗑️  To reset everything:"
echo "   docker compose down -v"
echo ""
echo "Good luck and happy hacking! 🚢"
echo ""
