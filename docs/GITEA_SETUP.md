# Gitea Setup Guide

This guide explains how to set up the Gitea repositories and users to match the original Titanic HTB machine.

## Automatic vs Manual Setup

The lab can be run in two modes:

1. **Simplified Mode** (Current): Gitea is running, but repositories need to be manually created
2. **Full Mode**: Use initialization scripts to pre-populate Gitea with users and repositories

For learning purposes, the simplified mode is recommended as it allows you to understand the structure.

## Manual Setup (Recommended for Learning)

### Step 1: Access Gitea

1. Ensure the lab is running:

   ```bash
   docker compose up -d
   ```

2. Wait for Gitea to initialize (check logs):

   ```bash
   docker compose logs -f gitea
   ```

3. Browse to http://dev.titanic.htb

### Step 2: Create Administrative User

1. Register the first user at http://dev.titanic.htb/user/sign_up
   - Username: `Administrator`
   - Email: `admin@titanic.htb`
   - Password: `Admin123!` (or your choice)

2. This user will be the admin automatically (first registered user)

### Step 3: Create Developer User

1. Log out and register a second user:
   - Username: `developer`
   - Email: `developer@titanic.htb`
   - Password: `25282528`

2. This user will have the crackable password

### Step 4: Create Repositories

Log in as the `developer` user and create two repositories:

#### Repository 1: docker-config

1. Click the "+" icon → New Repository
2. Fill in:
   - Repository Name: `docker-config`
   - Description: `Docker configuration files`
   - Visibility: **Public**
   - Initialize repository: **Yes**

3. Create the following structure:

**File: `mysql/docker compose.yml`**

```yaml
version: "3"

services:
  mysql:
    image: mysql:8.0
    container_name: titanic-mysql
    environment:
      MYSQL_ROOT_PASSWORD: MyS3cr3tR00tP@ssw0rd
      MYSQL_DATABASE: titanic_db
      MYSQL_USER: dbuser
      MYSQL_PASSWORD: dbP@ssw0rd123
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

**File: `gitea/docker compose.yml`**

```yaml
version: "3"

services:
  gitea:
    image: gitea/gitea:1.22.1
    container_name: gitea-server
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    volumes:
      - /home/developer/gitea/data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "2222:22"
```

**File: `README.md`**

````markdown
# Docker Configuration Repository

This repository contains Docker Compose configurations for various services used in the Titanic project.

## Services

- MySQL database
- Gitea server

## Setup

```bash
cd <service-directory>
docker compose up -d
```
````

````

#### Repository 2: flask-app

1. Create another repository:
   - Repository Name: `flask-app`
   - Description: `Titanic booking application`
   - Visibility: **Public**
   - Initialize repository: **Yes**

2. Add the Flask application code:

**File: `app.py`**
```python
from flask import Flask, render_template, request, jsonify, send_file
import os
import json
import uuid

app = Flask(__name__)

TICKETS_DIR = '/opt/app/tickets'
os.makedirs(TICKETS_DIR, exist_ok=True)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/book', methods=['POST'])
def book_ticket():
    try:
        data = request.get_json()

        name = data.get('name', '')
        email = data.get('email', '')
        phone = data.get('phone', '')
        date = data.get('date', '1912-04-15')
        cabin = data.get('cabin', 'Standard')

        ticket_data = {
            "name": name,
            "email": email,
            "phone": phone,
            "date": date,
            "cabin": cabin
        }

        ticket_id = f"ticket_{uuid.uuid4().hex[:16]}.json"
        ticket_path = os.path.join(TICKETS_DIR, ticket_id)

        with open(ticket_path, 'w') as f:
            json.dump(ticket_data, f, indent=2)

        return jsonify({
            "status": "success",
            "message": "Ticket booked successfully!",
            "ticket_id": ticket_id
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/download', methods=['GET'])
def download_ticket():
    ticket = request.args.get('ticket')

    if not ticket:
        return jsonify({"error": "Ticket parameter is required"}), 400

    # VULNERABILITY: No path sanitization
    json_filepath = os.path.join(TICKETS_DIR, ticket)

    if os.path.exists(json_filepath):
        return send_file(json_filepath, as_attachment=True, download_name=ticket)
    else:
        return jsonify({"error": "Ticket not found"}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
````

**File: `requirements.txt`**

```
Flask==3.0.0
```

**File: `README.md`**

````markdown
# Titanic Booking Application

A Flask web application for booking tickets on the RMS Titanic.

## Features

- Book tickets with passenger information
- Download booking confirmations as JSON
- Beautiful web interface

## Installation

```bash
pip install -r requirements.txt
python app.py
```
````

Access at http://localhost:5000

````

### Step 5: Verify Setup

1. Browse to http://dev.titanic.htb/developer/docker-config
2. Verify the docker compose.yml files are visible
3. Browse to http://dev.titanic.htb/developer/flask-app
4. Verify the app.py file is visible and shows the vulnerable code

## Automated Setup (Advanced)

For repeated deployments, you can use the Gitea API to automate repository creation.

### Using Gitea API

```bash
# Create a file with the Gitea token
GITEA_TOKEN="your-token-here"
GITEA_URL="http://dev.titanic.htb"

# Create repository
curl -X POST "$GITEA_URL/api/v1/user/repos" \
  -H "Authorization: token $GITEA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "docker-config",
    "description": "Docker configuration files",
    "private": false,
    "auto_init": true
  }'
````

## Database Pre-population (Expert Mode)

To pre-populate the Gitea database with the correct hashes:

1. Access the Gitea container:

   ```bash
   docker exec -it titanic-gitea /bin/bash
   ```

2. Use the Gitea CLI to create users:

   ```bash
   su - git
   gitea admin user create --username developer --password 25282528 --email developer@titanic.htb
   ```

3. Or directly modify the SQLite database:

   ```bash
   sqlite3 /data/gitea/gitea.db
   ```

   Insert the user with the correct hash:

   ```sql
   INSERT INTO user (
     name, email, passwd, passwd_hash_algo, salt,
     is_active, is_admin, created_unix, updated_unix
   ) VALUES (
     'developer',
     'developer@titanic.htb',
     'e531d398946137baea70ed6a680a54385ecff131309c0bd8f225f284406b7cbc8efc5dbef30bf1682619263444ea594cfb56',
     'pbkdf2',
     '8bf3e3452b78544f8bee9400d6936d34',
     1, 0,
     strftime('%s', 'now'),
     strftime('%s', 'now')
   );
   ```

## Verification

After setup, attackers should be able to:

1. Register on Gitea
2. See two users: Administrator and developer
3. Browse two public repositories
4. Find the Flask source code with the vulnerability
5. Find the docker compose file revealing the Gitea data path

## Troubleshooting

### Gitea won't start

```bash
docker compose logs gitea
```

Check for permission issues with the volume.

### Can't create repositories

Ensure you're logged in and have completed registration.

### Database issues

Reset Gitea data:

```bash
docker compose down
docker volume rm titanic_gitea-data
docker compose up -d
```

## Next Steps

Once Gitea is configured, proceed to the [WALKTHROUGH.md](WALKTHROUGH.md) for exploitation steps.
