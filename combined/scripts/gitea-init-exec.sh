#!/bin/bash

# Initialize Gitea using docker exec with git user
# This avoids permission issues and API authentication requirements

set -e

CONTAINER="titanic-gitea"

echo "Waiting for Gitea container to be healthy..."

# Wait for container to be ready
for i in {1..60}; do
    if docker inspect --format='{{.State.Health.Status}}' $CONTAINER 2>/dev/null | grep -q "healthy"; then
        echo "✓ Gitea container is healthy!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "✗ Gitea failed to become healthy"
        exit 1
    fi
    sleep 1
done

sleep 2

echo "Initializing Gitea users..."

# Create Administrator user
if ! docker exec -u git $CONTAINER gitea admin user list 2>/dev/null | grep -q "Administrator"; then
    echo "Creating Administrator user..."
    docker exec -u git $CONTAINER gitea admin user create \
        --username Administrator \
        --password Admin123! \
        --email admin@titanic.htb \
        --admin \
        2>/dev/null || echo "Administrator user may already exist"
else
    echo "✓ Administrator user already exists"
fi

sleep 1

# Create developer user
if ! docker exec -u git $CONTAINER gitea admin user list 2>/dev/null | grep -q "developer"; then
    echo "Creating developer user..."
    docker exec -u git $CONTAINER gitea admin user create \
        --username developer \
        --password 25282528 \
        --email developer@titanic.htb \
        --must-change-password=false \
        2>/dev/null || echo "Developer user may already exist"
else
    echo "✓ Developer user already exists"
    # If user already exists, ensure password change flag is cleared
    docker exec -u git $CONTAINER gitea admin user change-password \
        --username developer \
        --password 25282528 \
        2>/dev/null || true
fi

sleep 1

echo ""
echo "Initializing repositories..."

# Function to create repository via API
create_repo() {
    local repo_name=$1
    local description=$2
    
    # Check if repo already exists (from within container network)
    if docker exec $CONTAINER curl -sf "http://localhost:3000/api/v1/repos/developer/$repo_name" > /dev/null 2>&1; then
        echo "✓ $repo_name repository already exists"
        return 0
    fi
    
    echo "Creating repository: $repo_name"
    
    # Create as admin (using admin endpoint which doesn't require password change)
    docker exec $CONTAINER curl -X POST "http://localhost:3000/api/v1/admin/users/developer/repos" \
        -H "Content-Type: application/json" \
        --user "Administrator:Admin123!" \
        -d "{
            \"name\": \"$repo_name\",
            \"description\": \"$description\",
            \"private\": false,
            \"auto_init\": true,
            \"default_branch\": \"main\"
        }" \
        -w "\n" \
        -o /dev/null 2>&1
}

# Create repositories
create_repo "docker-config" "Docker configuration files"
sleep 1

create_repo "flask-app" "Titanic booking application"
sleep 2

echo ""
echo "Seeding repositories with code..."

# Call the seed script to populate repositories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/seed-repos.sh" ]; then
    bash "$SCRIPT_DIR/seed-repos.sh"
else
    echo "⚠ seed-repos.sh not found, repositories will be empty"
fi

echo ""
echo "✓ Gitea initialization complete!"
echo ""
echo "Access information:"
echo "  Web UI: http://dev.titanic.htb:8080"
echo "  Administrator Username: Administrator"
echo "  Administrator Password: Admin123!"
echo "  Developer Username: developer"
echo "  Developer Password: 25282528"
echo ""
echo "Created Repositories:"
echo "  • docker-config"
echo "  • flask-app"
