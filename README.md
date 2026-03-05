# Titanic HTB Lab Recreation

This is a complete recreation of the Titanic HackTheBox machine, designed to run in isolated Docker containers for learning and practice purposes.

## Lab Overview

**Difficulty Level**: Easy  
**Operating System**: Linux  
**Primary Skills**: Web Exploitation, Hash Cracking, Privilege Escalation

### Learning Objectives

- Web enumeration and virtual host discovery
- Directory traversal vulnerabilities
- Password hash extraction and cracking (PBKDF2-SHA256)
- CVE exploitation (ImageMagick CVE-2024-41817)
- Linux privilege escalation techniques

## Architecture

The lab consists of 2 Docker containers:

1. **gitea** - Git repository server (dev.titanic.htb) with SSH access
2. **combined** - Combined container with:
   - nginx - Reverse proxy for virtual host routing
   - flask-app - Vulnerable Flask web application (titanic.htb)
   - target - SSH server with privilege escalation vulnerability

## Deployment Options

### Local Testing (Docker Compose)

Quick and easy deployment using docker-compose:

```bash
docker compose up -d
```

### Production Deployment

The lab consists of 2 self-contained Docker images ready for any container platform:

**Quick Guide:** See [BUILD_AND_PUSH.md](BUILD_AND_PUSH.md) for step-by-step instructions.

1. **Build the images:**

   ```bash
   docker build -t titanic-gitea:latest ./gitea
   docker build -t titanic-combined:latest ./combined
   ```

2. **Push to registry:**

   ```bash
   docker tag titanic-gitea:latest your-registry/titanic-gitea:latest
   docker tag titanic-combined:latest your-registry/titanic-combined:latest
   docker push your-registry/titanic-gitea:latest
   docker push your-registry/titanic-combined:latest
   ```

3. **Platform Configuration:** Provide [RUNTIME_REQUIREMENTS.md](RUNTIME_REQUIREMENTS.md) to the platform

**Manual Docker Commands:** See [MANUAL_BUILD.md](MANUAL_BUILD.md) for manual deployment.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB of available RAM
- 10GB of free disk space
- Basic understanding of Linux and networking

## Quick Start

### 1. Add DNS Entries

Add the following entries to your `/etc/hosts` file:

```bash
127.0.0.1 titanic.htb dev.titanic.htb
```

### 2. Build and Start the Lab

```bash
# Clone or navigate to the lab directory
cd titanic

# Build all containers
docker compose build

# Start the lab
docker compose up -d

# Check container status
docker compose ps
```

### 3. Wait for Services to Initialize

Gitea automatically initializes with users and repositories. This takes about 1-2 minutes. You can monitor the process:

```bash
docker compose logs -f gitea
```

Once you see "Gitea is running..." message, everything is ready!

## Access the Lab

All services are now automatically set up:

1. **Main Website**: http://titanic.htb:8080
   - Book tickets and exploit directory traversal

2. **Gitea Server**: http://dev.titanic.htb:8080
   - Login with developer / 25282528
   - Explore public repositories:
     - `docker-config` - Contains Docker Compose configurations
     - `flask-app` - Contains Flask application source code

3. **SSH Access**: Port 2223
   - Command: `ssh developer@localhost -p 2223`
   - Password: `25282528`

**Pre-created Users:**

- **developer**: Password `25282528` (the target user for exploitation)
- **Administrator**: Password `Admin123!` (admin account)

## Attack Surface

### Open Ports

- **Port 8080** (HTTP):
  - titanic.htb:8080 - Flask booking application
  - dev.titanic.htb:8080 - Gitea server
- **Port 3222** (SSH): Gitea SSH server
- **Port 2223** (SSH): Target machine SSH access

### Vulnerabilities

1. **Directory Traversal (Flask App)**
   - Location: `/download?ticket=` endpoint
   - Impact: Arbitrary file read as flask user

2. **Information Disclosure (Gitea)**
   - Public repositories expose configuration
   - Database location revealed
   - Source code with vulnerabilities

3. **Weak Credentials**
   - Developer password: `25282528`
   - Can be cracked from Gitea database

4. **Privilege Escalation (ImageMagick CVE-2024-41817)**
   - Vulnerable version: 7.1.1-35
   - Cron job running as root
   - Exploitable via LD_LIBRARY_PATH injection

## Flags

- **User Flag**: `/home/developer/user.txt`
- **Root Flag**: `/root/root.txt`

## Exploitation Path (High-Level)

1. Enumerate titanic.htb and discover dev.titanic.htb subdomain
2. Register on Gitea and explore public repositories
3. Find Flask app source code revealing directory traversal vulnerability
4. Exploit directory traversal to download Gitea database
5. Extract and crack developer password hash
6. SSH into target machine as developer
7. Enumerate system and find vulnerable ImageMagick script
8. Exploit CVE-2024-41817 to escalate to root

See [WALKTHROUGH.md](docs/WALKTHROUGH.md) for a detailed exploitation guide.

## Stopping the Lab

```bash
# Stop all containers
docker compose down

# Stop and remove all data (clean reset)
docker compose down -v
```

## Troubleshooting

### Container won't start

```bash
# Check logs
docker compose logs <service-name>

# Rebuild a specific service
docker compose build --no-cache <service-name>
```

### Can't access web interfaces

1. Verify containers are running: `docker compose ps`
2. Check `/etc/hosts` has correct entries
3. Verify nginx is routing correctly: `docker compose logs nginx`

### SSH connection refused

The target container needs a moment to start SSH. Wait 10-15 seconds after `docker compose up` completes.

```bash
# Test SSH connection
ssh developer@localhost -p 2222
# Password: 25282528
```

## Security Notes

⚠️ **WARNING**: This lab contains intentional vulnerabilities.

- Only run in isolated environments
- Do NOT expose to public networks
- Do NOT use any credentials from this lab in production
- The vulnerabilities are for educational purposes only

## File Structure

```
titanic/
├── docker compose.yml          # Main orchestration file
├── Dockerfile.target           # Target machine (SSH + vulnerabilities)
├── README.md                   # This file
├── flask-app/                  # Vulnerable web application
│   ├── Dockerfile
│   ├── app.py                  # Main Flask app with directory traversal
│   ├── requirements.txt
│   └── templates/
│       └── index.html
├── gitea/                      # Gitea configuration
│   ├── Dockerfile
│   └── app.ini                 # Gitea settings
├── nginx/                      # Reverse proxy
│   └── nginx.conf              # Virtual host routing
├── scripts/                    # Privilege escalation scripts
│   └── identify_images.sh      # Vulnerable ImageMagick script
└── docs/                       # Documentation
    ├── WALKTHROUGH.md          # Complete exploitation guide
    ├── GITEA_SETUP.md          # How to set up Gitea repos
    └── EXPLOITATION_DETAILS.md # Technical details of each vuln
```

## Credits

- Original machine created by ruycr4ft on HackTheBox
- Writeup reference: https://medium.com/@fharing42/titanic-htb-writeup-88733278d312
- Lab recreation for educational purposes

## License

This lab is for educational purposes only. Use responsibly and ethically.

## Support

If you encounter issues or have questions about the lab setup, please check:

1. Container logs: `docker compose logs`
2. Documentation in the `docs/` folder
3. Verify all prerequisites are met
