# Titanic Lab - Platform Requirements

This document describes what the platform needs to configure to run these images.

## Images

1. **titanic-gitea:latest** - Git repository server
2. **titanic-combined:latest** - Web app + target environment (requires privileged mode)

## What's Already Included in the Images

✅ **Environment Variables:**

- `USER_UID=1000`
- `USER_GID=1000`

✅ **Exposed Ports:**

- gitea: 3000 (HTTP), 2222 (SSH)
- combined: 80 (HTTP), 22 (SSH)

✅ **Configuration:**

- app.ini (Gitea config)
- nginx-combined.conf (Web server config)
- Flask application
- All scripts and initialization

---

## What the Platform Needs to Configure

### 1. Volumes (Persistent Storage)

Create and mount two volumes:

**For titanic-gitea:**

- Mount point: `/data`
- Purpose: Gitea data persistence
- Type: Read-write (git repositories, config, user data)

**For titanic-combined:**

- Mount point: `/home/developer/gitea/data`
- Purpose: Read-only access to Gitea data (shared)
- Read-only: YES
- Mount from: same volume as gitea `/data`

- Mount point: `/opt/app/tickets`
- Purpose: User uploads and tickets storage
- Type: Read-write

### 2. Networking

Create network bridge and assign static IPs (optional but recommended):

**Suggested Configuration:**

- Network: 10.20.0.0/16
- Gitea IP: 10.20.0.12
- Combined IP: 10.20.0.11

**Requirements:**

- Both containers must be able to communicate
- Combined container needs to reach Gitea at `http://10.20.0.12:3000` or via hostname `gitea`

### 3. Security Context

**For titanic-combined container only:**

- Set `privileged: true` or `securityContext.privileged: true`
- Required for: cron daemon, privilege escalation scenarios

### 4. Port Exposure

Expose container ports to users:

**gitea Pod:**

- Port 3000 → HTTP (Gitea web interface) - optional
- Port 2222 → SSH (Gitea SSH) - optional

**combined Pod:**

- Port 80 → HTTP (Main web interface) - **required**
- Port 22 → SSH (User SSH access) - **required**

---

## Platform Configuration Example

```yaml
# Pseudo-config for reference
pods:
  - name: titanic-gitea
    image: titanic-gitea:latest
    volumes:
      - name: gitea-data
        mount: /data
    network:
      ip: 10.20.0.12

  - name: titanic-combined
    image: titanic-combined:latest
    privileged: true
    volumes:
      - name: gitea-data
        mount: /home/developer/gitea/data
        readOnly: true
      - name: tickets-data
        mount: /opt/app/tickets
    network:
      ip: 10.20.0.11
    ports:
      - 80
      - 22
```

---

## User Access

After deployment, users can access:

**SSH Access (combined):**

```bash
ssh developer@<combined-ip-or-hostname> -p 22
# Password: 25282528
```

**Web Interface (combined):**

```
http://<combined-ip-or-hostname>:80
```

**Gitea (optionally exposed):**

```
http://<gitea-ip-or-hostname>:3000
```

---

## Summary

The images are **fully self-contained**. The platform only needs to:

1. ✅ Create 2 persistent volumes
2. ✅ Mount them into the containers at correct paths
3. ✅ Create a network bridge and assign IPs
4. ✅ Set `privileged: true` for combined container
5. ✅ Expose ports to users

That's it! No additional configuration needed.
