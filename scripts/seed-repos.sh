#!/bin/bash

# Seed Gitea repositories with initial code
# This script populates the repositories after they're created

set -e

GITEA_HOST="dev.titanic.htb:8080"
GITEA_USER="developer"
GITEA_PASS="25282528"
WORK_DIR="/tmp/gitea-seed-$$"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Navigate to the titanic directory (parent of scripts)
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SEED_DIR="$BASE_DIR/repo-seed"

echo "Seeding Gitea repositories with code..."
echo "Using seed directory: $SEED_DIR"

# Create temporary working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Function to seed a repository
seed_repo() {
    local repo_name=$1
    local seed_path=$2
    
    echo "Seeding repository: $repo_name"
    
    # Clone the repository
    git clone "http://${GITEA_USER}:${GITEA_PASS}@${GITEA_HOST}/${GITEA_USER}/${repo_name}.git" 2>/dev/null || {
        echo "Failed to clone $repo_name, skipping..."
        return 1
    }
    
    cd "$repo_name"
    
    # Configure git
    git config user.email "developer@titanic.htb"
    git config user.name "developer"
    
    # Copy seed files (excluding .git directory)
    cp -r "$seed_path"/* ./ 2>/dev/null || {
        echo "Failed to copy files for $repo_name"
        cd ..
        return 1
    }
    
    # Copy hidden files if any
    cp -r "$seed_path"/.[!.]* ./ 2>/dev/null || true
    
    # Add all files
    git add .
    
    # Commit
    git commit -m "Initial commit - Add project files" 2>/dev/null || {
        echo "Nothing to commit for $repo_name"
        cd ..
        return 0
    }
    
    # Determine the default branch
    DEFAULT_BRANCH=$(git branch --show-current)
    if [ -z "$DEFAULT_BRANCH" ]; then
        DEFAULT_BRANCH="main"
    fi
    
    # Push to the default branch
    git push -u origin "$DEFAULT_BRANCH" 2>&1 | grep -v "Username\|Password" || {
        echo "Failed to push $repo_name to $DEFAULT_BRANCH"
        cd ..
        return 1
    }
    
    echo "✓ Successfully seeded $repo_name"
    cd ..
}

# Wait a moment for repositories to be fully initialized
sleep 2

# Seed docker-config repository
if [ -d "$SEED_DIR/docker-config" ]; then
    seed_repo "docker-config" "$SEED_DIR/docker-config"
else
    echo "⚠ docker-config seed directory not found at $SEED_DIR/docker-config"
fi

sleep 1

# Seed flask-app repository
if [ -d "$SEED_DIR/flask-app" ]; then
    seed_repo "flask-app" "$SEED_DIR/flask-app"
else
    echo "⚠ flask-app seed directory not found at $SEED_DIR/flask-app"
fi

# Cleanup
cd /
rm -rf "$WORK_DIR"

echo ""
echo "✓ Repository seeding complete!"
