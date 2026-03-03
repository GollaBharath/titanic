#!/bin/bash

# Gitea initialization script
# Starts Gitea and initializes it with users and repositories

# Start Gitea
echo "Starting Gitea server..."
/usr/local/bin/gitea web -c /data/gitea/conf/app.ini &
GITEA_PID=$!

# Wait for Gitea to be ready (max 120 seconds)
echo "Waiting for Gitea to initialize..."
for i in {1..120}; do
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo "✓ Gitea is ready!"
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "Still waiting... ($i/120s)"
    fi
    sleep 1
done

# Give Gitea a moment to fully initialize
sleep 3

# Check if users need to be created
echo "Setting up users and repositories..."

# Function to create user via admin command
create_user() {
    local username=$1
    local password=$2
    local email=$3
    local is_admin=${4:-false}
    
    echo "Creating user: $username"
    su - git -c "gitea admin user create --username '$username' --password '$password' --email '$email' --admin=$is_admin" 2>/dev/null || echo "User $username may already exist"
}

# Create users
create_user "developer" "25282528" "developer@titanic.htb" "false"
create_user "Administrator" "Admin123!" "admin@titanic.htb" "true"

sleep 2

# Create repositories
echo "Creating repositories..."

# Create docker-config repo
su - git -c "gitea admin repo create-from-template --template-owner gitea --template-name '' --owner developer --name docker-config --description 'Docker configuration files' --public" 2>/dev/null || echo "Repository docker-config may already exist"

# Create flask-app repo  
su - git -c "gitea admin repo create-from-template --template-owner gitea --template-name '' --owner developer --name flask-app --description 'Titanic booking application' --public" 2>/dev/null || echo "Repository flask-app may already exist"

echo "✓ Initialization complete"
echo ""
echo "Gitea is running..."
echo "  Web UI: http://dev.titanic.htb:8080"
echo "  SSH: localhost:3222"
echo ""

# Keep Gitea running
wait $GITEA_PID

