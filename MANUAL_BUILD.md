# Manual Build and Run Instructions

This document contains the commands to manually build and run the Titanic lab without using docker-compose.

## Quick Start (Docker)

For the simplest deployment with docker-compose:

```bash
docker compose up -d
```

## Manual Docker Deployment

## 1. Build Images

Build the Gitea image:

```bash
cd /home/dead/TT/lab/titanic/gitea
docker build -t titanic-gitea:latest .
```

Build the Combined image:

```bash
cd /home/dead/TT/lab/titanic/combined
docker build -t titanic-combined:latest .
```

## 2. Create Network

Create the Docker network with the required subnet:

```bash
docker network create --driver bridge --subnet 10.20.0.0/16 titanic-net
```

## 3. Start Gitea Container

**Note:** Docker will automatically create the required volumes (`gitea-data` and `tickets-data`) when starting the containers.

Start the Gitea container with all required configuration:

```bash
docker run -d \
  --name titanic-gitea \
  --network titanic-net \
  --ip 10.20.0.12 \
  -e USER_UID=1000 \
  -e USER_GID=1000 \
  -v gitea-data:/data \
  -p 3222:2222 \
  titanic-gitea:latest
```

## 4. Start Combined Container

Start the Combined container with all required configuration:

```bash
docker run -d \
  --name titanic-combined \
  --hostname titanic \
  --network titanic-net \
  --ip 10.20.0.11 \
  --privileged \
  -v gitea-data:/home/developer/gitea/data:ro \
  -v tickets-data:/opt/app/tickets \
  -p 8080:80 \
  -p 2223:22 \
  titanic-combined:latest
```

## 5. Verify Containers

Check that both containers are running:

```bash
docker ps --filter "name=titanic-"
```

Check the combined container logs:

```bash
docker logs titanic-combined
```

Test network connectivity between containers:

```bash
docker exec titanic-combined curl -s -o /dev/null -w "%{http_code}" http://10.20.0.12:3000/
```

Should return: 200

Test external access:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/
```

Should return: 200

## 6. Stop and Clean Up

Stop and remove containers:

```bash
docker stop titanic-gitea titanic-combined
docker rm titanic-gitea titanic-combined
```

Remove network:

```bash
docker network rm titanic-net
```

Remove volumes (WARNING: This will delete all data):

```bash
docker volume rm gitea-data tickets-data
```

## Notes

- Docker automatically creates named volumes when they are first referenced in `docker run` commands, so no manual volume creation is needed
- All configuration files are baked into the Docker images for easier deployment
- The gitea container must be started first and healthy before the combined container starts
- Both containers communicate over the `titanic-net` network with static IPs:
  - Gitea: 10.20.0.12
  - Combined: 10.20.0.11
- The combined container requires `--privileged` mode for cron and system access
- External access:
  - Web interface (nginx): http://localhost:8080
  - SSH (combined): ssh://localhost:2223
  - SSH (gitea): ssh://localhost:3222

---

## Production Deployment

For production platforms, see [RUNTIME_REQUIREMENTS.md](RUNTIME_REQUIREMENTS.md) for the runtime configuration needed by the platform to run these images.
