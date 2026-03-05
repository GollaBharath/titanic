# Titanic Docker Configuration

This repository contains the Docker Compose configuration for the Titanic booking system development environment.

## Services

- **MySQL**: Database server for storing booking data
- **Gitea**: Git hosting service for code management
- **Web**: Flask web application

## Setup

1. Ensure Docker and Docker Compose are installed
2. Run: `docker-compose up -d`
3. Access the web interface at http://localhost:5000
4. Access Gitea at http://localhost:3000

## Notes

- Gitea data is persisted in `/home/developer/gitea/data`
- MySQL data is stored in a Docker volume
- Default MySQL credentials are configured in the compose file
