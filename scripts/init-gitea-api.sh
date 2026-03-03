#!/bin/bash

# Initialize Gitea with users and repositories via API
# This script waits for Gitea to be ready and then sets up everything

set -e

GITEA_URL="http://gitea:3000"
GITEA_API="$GITEA_URL/api/v1"
MAX_RETRIES=120
RETRY_COUNT=0

echo "Waiting for Gitea to become ready..."

# Wait for Gitea to respond
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf "$GITEA_URL" > /dev/null 2>&1; then
        echo "✓ Gitea is responding!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
        echo "Still waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    fi
    sleep 1
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ Gitea failed to start within timeout"
    exit 1
fi

sleep 3

echo "Initializing Gitea..."

# Check if users already exist (check if initialized)
if curl -sf "$GITEA_API/users/Administrator" > /dev/null 2>&1; then
    echo "✓ Gitea already initialized, skipping user creation"
else
    echo "Setting up initial admin user via install endpoint..."
    
    # Try the install endpoint (only available before first user is created)
    INSTALL_RESPONSE=$(curl -s -X POST "$GITEA_URL/api/v1/admin/install" \
        -H "Content-Type: application/json" \
        -d '{
            "admin_user": "Administrator",
            "admin_password": "Admin123!",
            "admin_email": "admin@titanic.htb"
        }')
    
    echo "Install response: $INSTALL_RESPONSE"
    
    # Wait a bit for the admin user to be created
    sleep 2
    
    # Now create the developer user (should work with admin auth now)
    echo "Creating developer user..."
    curl -X POST "$GITEA_API/admin/users" \
        -H "Content-Type: application/json" \
        --user "Administrator:Admin123!" \
        -d '{
            "username": "developer",
            "email": "developer@titanic.htb",
            "password": "25282528",
            "must_change_password": false
        }' 2>/dev/null || echo "Developer user may already exist"
fi

sleep 2

# Create repositories via developer user
echo "Creating repositories..."

# Check if repos already exist
if ! curl -sf "$GITEA_API/repos/developer/docker-config" > /dev/null 2>&1; then
    echo "Creating repository: developer/docker-config"
    curl -X POST "$GITEA_API/user/repos" \
        -H "Content-Type: application/json" \
        --user "developer:25282528" \
        -d '{
            "name": "docker-config",
            "description": "Docker configuration files",
            "private": false,
            "auto_init": true
        }' 2>/dev/null || echo "Failed to create docker-config repository"
    sleep 1
fi

if ! curl -sf "$GITEA_API/repos/developer/flask-app" > /dev/null 2>&1; then
    echo "Creating repository: developer/flask-app"
    curl -X POST "$GITEA_API/user/repos" \
        -H "Content-Type: application/json" \
        --user "developer:25282528" \
        -d '{
            "name": "flask-app",
            "description": "Titanic booking application",
            "private": false,
            "auto_init": true
        }' 2>/dev/null || echo "Failed to create flask-app repository"
    sleep 1
fi

echo ""
echo "✓ Gitea initialization complete!"
echo ""
echo "Access information:"
echo "  Web UI: http://dev.titanic.htb:8080"
echo "  Username: developer"
echo "  Password: 25282528"
echo "  Admin Username: Administrator"
echo "  Admin Password: Admin123!"
echo ""
