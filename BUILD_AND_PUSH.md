# Building and Pushing Titanic Lab Images

Simple guide to build and push the 2 Docker images to your registry.

## Quick Start

```bash
# 1. Build both images
docker build -t titanic-gitea:latest ./gitea
docker build -t titanic-combined:latest ./combined

# 2. Tag for your registry
docker tag titanic-gitea:latest your-registry/titanic-gitea:latest
docker tag titanic-combined:latest your-registry/titanic-combined:latest

# 3. Push to registry
docker push your-registry/titanic-gitea:latest
docker push your-registry/titanic-combined:latest
```

## Step by Step

### 1. Build Images

```bash
# Build Gitea image
cd /home/dead/TT/lab/titanic/gitea
docker build -t titanic-gitea:latest .

# Build Combined image
cd /home/dead/TT/lab/titanic/combined
docker build -t titanic-combined:latest .
```

Verify:

```bash
docker images | grep titanic
```

### 2. Tag for Registry

Replace `your-registry` with your actual registry URL:

```bash
docker tag titanic-gitea:latest your-registry/titanic-gitea:latest
docker tag titanic-combined:latest your-registry/titanic-combined:latest
```

**Registry Examples:**

- Docker Hub: `username/titanic-gitea:latest`
- GitHub Container Registry: `ghcr.io/username/titanic-gitea:latest`
- Private registry: `registry.example.com/titanic-gitea:latest`

### 3. Push to Registry

```bash
# Login (if needed)
docker login your-registry

# Push both images
docker push your-registry/titanic-gitea:latest
docker push your-registry/titanic-combined:latest
```

### 4. Verify

```bash
docker pull your-registry/titanic-gitea:latest
docker pull your-registry/titanic-combined:latest
```

## Image Sizes

- **titanic-gitea:latest** → ~200MB
- **titanic-combined:latest** → ~1.5GB

Total: ~1.7GB

## What's Included (Already in Images)

✅ Environment variables (USER_UID=1000, USER_GID=1000)
✅ All exposed ports (gitea: 3000, 2222 | combined: 80, 22)
✅ All configuration files
✅ All scripts and applications

## Testing Locally

Before pushing, test locally with docker-compose:

```bash
cd /home/dead/TT/lab/titanic
docker compose build
docker compose up -d
curl http://localhost:8080
docker compose down
```

If the test passes, the images are ready to push!

## Give to Platform

After pushing, provide to platform admins:

1. **Image URLs:**
   - `your-registry/titanic-gitea:latest`
   - `your-registry/titanic-combined:latest`

2. **Configuration Reference:**
   - See [RUNTIME_REQUIREMENTS.md](RUNTIME_REQUIREMENTS.md)

```bash
# Login to registry (if needed)
docker login your-registry

# Push both images
docker push your-registry/titanic-gitea:latest
docker push your-registry/titanic-combined:latest
```

## 4. Verify Upload

```bash
# Pull to verify
docker pull your-registry/titanic-gitea:latest
docker pull your-registry/titanic-combined:latest
```

## Image Information

### titanic-gitea:latest

- **Size:** ~200MB (based on gitea/gitea:1.22.1)
- **Contains:** Gitea server with pre-configured app.ini
- **Purpose:** Git repository server for the lab

### titanic-combined:latest

- **Size:** ~1.5GB (Ubuntu 22.04 + ImageMagick + nginx + Python)
- **Contains:** Web app + target environment with all configurations
- **Purpose:** Vulnerable web application and exploitation target

## What the Platform Needs

After uploading the images, provide the platform with:

1. **Image URLs:**
   - `your-registry/titanic-gitea:latest`
   - `your-registry/titanic-combined:latest`

2. **Runtime Requirements:** See [RUNTIME_REQUIREMENTS.md](RUNTIME_REQUIREMENTS.md)

The platform will handle:

- Creating pods from the images
- Setting up networking between containers
- Configuring volumes for persistence
- Exposing ports for user access
- Setting security context (privileged mode for combined)

## Testing Locally

Before pushing, test the images work:

```bash
cd /home/dead/TT/lab/titanic
docker compose up -d
docker compose ps
curl http://localhost:8080
docker compose down
```

If the local test works, the images are ready to push!
