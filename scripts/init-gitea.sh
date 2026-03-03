#!/bin/bash

# Initialize Gitea with pre-configured users and repositories

GITEA_URL="http://dev.titanic.htb"
ADMIN_USER="developer"
ADMIN_PASS="25282528"

echo "Waiting for Gitea to be ready..."
sleep 30

# Function to create repository
create_repo() {
    local repo_name=$1
    local description=$2
    
    echo "Creating repository: $repo_name"
    
    curl -X POST "$GITEA_URL/api/v1/user/repos" \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$repo_name\",
            \"description\": \"$description\",
            \"private\": false,
            \"auto_init\": true
        }"
}

# Create repositories
create_repo "docker-config" "Docker configuration files"
create_repo "flask-app" "Titanic booking application"

echo "Repositories created successfully!"
