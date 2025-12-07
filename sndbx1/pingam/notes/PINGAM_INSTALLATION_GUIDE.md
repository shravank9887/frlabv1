# PingAM Installation Guide - Docker Setup

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Step 1: Prepare Directory Structure](#step-1-prepare-directory-structure)
4. [Step 2: Create Dockerfile](#step-2-create-dockerfile)
5. [Step 3: Update Docker Compose](#step-3-update-docker-compose)
6. [Step 4: Prepare PingDS Data Stores](#step-4-prepare-pingds-data-stores)
7. [Step 5: Deploy PingAM Container](#step-5-deploy-pingam-container)
8. [Step 6: Configure PingAM](#step-6-configure-pingam)
9. [Step 7: Verify Installation](#step-7-verify-installation)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### What You Have
✅ PingDS container running (`pingds`)
✅ User store with sample users (`ou=identities`)
✅ Docker and Docker Compose installed
✅ Network: `fr-net` created

### What You Need
- [ ] PingAM WAR file (AM-8.0.2.war)
- [ ] Apache Tomcat 9.x base image
- [ ] Java 11 or 17
- [ ] 2GB+ RAM for AM container

---

## Architecture Overview

### Final Setup

```
┌──────────────────────┐         ┌──────────────────────┐
│    PingDS Container  │         │   PingAM Container   │
│                      │         │                      │
│  Port 1389 (LDAP)    │◄────────┤  Apache Tomcat 9.x   │
│  Port 1636 (LDAPS)   │  LDAPS  │  Port 8080 (HTTP)    │
│  Port 4444 (Admin)   │         │  Port 8443 (HTTPS)   │
│                      │         │                      │
│  ┌────────────────┐  │         │  WAR: /am            │
│  │ ou=am-config   │  │         │  Context: /am        │
│  │ (Config Store) │  │         │                      │
│  ├────────────────┤  │         └──────────────────────┘
│  │ ou=tokens      │  │                   │
│  │ (CTS Store)    │  │                   │ User Access
│  ├────────────────┤  │                   ▼
│  │ ou=identities  │  │         ┌──────────────────────┐
│  │ (User Store)   │  │         │   Web Browser        │
│  └────────────────┘  │         │  http://localhost:   │
└──────────────────────┘         │  8080/am             │
                                 └──────────────────────┘
```

---

## Step 1: Prepare Directory Structure

### Create AM Directory Structure

```bash
cd /c/PCFolders/Main/Learning/Docker/fr/sndbx1

# Create directory structure for PingAM
mkdir -p pingam/{config,software,scripts,logs}
mkdir -p pingam/notes  # Already exists
```

### Directory Purpose

```
pingam/
├── Dockerfile              # AM container definition
├── config/                 # AM configuration files
├── software/               # AM WAR file goes here
├── scripts/                # Helper scripts
├── logs/                   # Application logs (mounted)
├── notes/                  # Documentation (already created)
└── resources.md            # Reference documentation links
```

---

## Step 2: Create Dockerfile

Create `pingam/Dockerfile`:

```dockerfile
# PingAM (Access Manager) Dockerfile
FROM tomcat:9-jdk17

# Maintainer information
LABEL maintainer="your-email@example.com"
LABEL description="PingAM 8.0.2 on Apache Tomcat 9 with JDK 17"

# Environment variables
ENV CATALINA_HOME=/usr/local/tomcat \
    AM_HOME=/opt/am \
    AM_CONFIG_DIR=/opt/am-config \
    JAVA_OPTS="-server -Xmx2g -XX:+UseG1GC"

# Create directories
RUN mkdir -p ${AM_HOME} ${AM_CONFIG_DIR} && \
    chmod 755 ${AM_HOME} ${AM_CONFIG_DIR}

# Remove default Tomcat webapps
RUN rm -rf ${CATALINA_HOME}/webapps/*

# Copy AM WAR file
# Note: You need to place AM-8.0.2.war in pingam/software/ first
COPY software/AM-8.0.2.war ${CATALINA_HOME}/webapps/am.war

# Create truststore directory
RUN mkdir -p ${CATALINA_HOME}/conf/keystores

# Set permissions
RUN chmod -R 755 ${CATALINA_HOME}/webapps && \
    chown -R root:root ${CATALINA_HOME}

# Expose ports
EXPOSE 8080 8443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=120s \
  CMD curl -f http://localhost:8080/am/isAlive.jsp || exit 1

# Start Tomcat
CMD ["catalina.sh", "run"]
```

---

## Step 3: Update Docker Compose

Update `docker-compose.yaml` to add PingAM service:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json

services:
  # Existing PingDS service
  pingds:
    build:
      context: ./pingds
      dockerfile: Dockerfile
    image: pingds:latest
    container_name: pingds
    hostname: pingds
    networks:
      fr-net:
        aliases:
          - pingds
          - ds.example.com
    ports:
      - "1389:1389"   # LDAP
      - "1636:1636"   # LDAPS
      - "4444:4444"   # Admin connector
      - "8080:8080"   # HTTP
      - "8443:8443"   # HTTPS
    environment:
      - DS_HOSTNAME=pingds
      - DS_SERVER_ID=ds-server-01
      - DS_DEPLOYMENT_ID=forgerock-eval
      - DS_DEPLOYMENT_PASSWORD=Passw0rd123
      - DS_ROOT_PASSWORD=Passw0rd123
      - DS_MONITOR_PASSWORD=Passw0rd123
      - AM_CONFIG_PASSWORD=Passw0rd123
      - AM_IDENTITY_PASSWORD=Passw0rd123
      - OPENDJ_JAVA_ARGS=-server -Xmx1g -XX:+UseG1GC
    volumes:
      - pingds-data:/opt/pingds-data
      - shared-certs:/opt/certs
      - pingds-backups:/opt/backups
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "/opt/opendj/bin/status", "--hostname", "pingds", "--port", "4444", "--bindDN", "cn=Directory Manager", "--bindPassword", "Passw0rd123", "--trustAll"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s

  # New PingAM service
  pingam:
    build:
      context: ./pingam
      dockerfile: Dockerfile
    image: pingam:latest
    container_name: pingam
    hostname: pingam
    networks:
      fr-net:
        aliases:
          - pingam
          - am.example.com
    ports:
      - "8081:8080"   # HTTP (mapped to 8081 to avoid conflict)
      - "8444:8443"   # HTTPS
    environment:
      # Java options
      - JAVA_OPTS=-server -Xmx2g -XX:+UseG1GC -Djavax.net.ssl.trustStore=/usr/local/tomcat/conf/keystores/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit

      # AM server settings
      - AM_SERVER_FQDN=pingam
      - AM_SERVER_PORT=8080
      - AM_SERVER_PROTOCOL=http

      # File-based configuration (optional - for automated setup)
      # - com.sun.identity.sm.sms_object_filebased_enabled=true
      # - com.sun.identity.configuration.directory=/opt/am-config
    volumes:
      - pingam-config:/opt/am-config
      - pingam-logs:/usr/local/tomcat/logs
      - shared-certs:/opt/certs
    depends_on:
      pingds:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/am/isAlive.jsp"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

# Named volumes for data persistence
volumes:
  pingds-data:
    name: forgerock_pingds_data
    driver: local

  shared-certs:
    name: forgerock_shared_certs
    driver: local

  pingds-backups:
    name: forgerock_pingds_backups
    driver: local

  pingam-config:
    name: forgerock_pingam_config
    driver: local

  pingam-logs:
    name: forgerock_pingam_logs
    driver: local

# External network (already created)
networks:
  fr-net:
    external: true
    name: fr-net
```

---

## Step 4: Prepare PingDS Data Stores

Before starting PingAM, prepare the data stores in PingDS.

### Quick Setup Script

Create `pingds/scripts/setup-am-datastores.sh`:

```bash
#!/bin/bash
# Setup PingDS for PingAM data stores

echo "==================================="
echo "Setting up PingDS for PingAM"
echo "==================================="

# Step 1: Create backends
echo "Creating backends..."
docker exec pingds /opt/opendj/bin/dsconfig create-backend \
  --hostname pingds --port 4444 \
  --bindDN "cn=Directory Manager" --bindPassword "Passw0rd123" \
  --backend-name amConfig --type je \
  --set enabled:true --set base-dn:ou=am-config \
  --trustAll --no-prompt

docker exec pingds /opt/opendj/bin/dsconfig create-backend \
  --hostname pingds --port 4444 \
  --bindDN "cn=Directory Manager" --bindPassword "Passw0rd123" \
  --backend-name amTokens --type je \
  --set enabled:true --set base-dn:ou=tokens \
  --trustAll --no-prompt

# Step 2: Import base structure
echo "Importing base structure..."
docker cp pingds/am-base-structure.ldif pingds:/tmp/
docker exec pingds /opt/opendj/bin/ldapmodify \
  --hostname pingds --port 1636 --useSSL --trustAll \
  --bindDN "cn=Directory Manager" --bindPassword "Passw0rd123" \
  --filename /tmp/am-base-structure.ldif

# Step 3: Create service accounts
echo "Creating service accounts..."
docker cp pingds/am-service-accounts.ldif pingds:/tmp/
docker exec pingds /opt/opendj/bin/ldapmodify \
  --hostname pingds --port 1636 --useSSL --trustAll \
  --bindDN "cn=Directory Manager" --bindPassword "Passw0rd123" \
  --filename /tmp/am-service-accounts.ldif

echo "==================================="
echo "PingDS setup complete!"
echo "==================================="
```

### Run Setup

```bash
chmod +x pingds/scripts/setup-am-datastores.sh
./pingds/scripts/setup-am-datastores.sh
```

**Note:** Refer to `DATA_STORES_PREPARATION.md` for detailed manual steps.

---

## Step 5: Deploy PingAM Container

### Place AM WAR File

First, you need to obtain the AM WAR file:

```bash
# Download from Ping Identity or ForgeRock Backstage
# Place it in: pingam/software/AM-8.0.2.war
```

**Note:** For evaluation, download from Ping Identity website.

---

### Build and Start Container

```bash
# Build the image
docker-compose build pingam

# Start PingAM (PingDS should already be running)
docker-compose up -d pingam

# Watch logs
docker-compose logs -f pingam
```

### Wait for Deployment

AM takes 2-3 minutes to fully deploy. Watch for:

```
INFO: Deployment of web application archive [/usr/local/tomcat/webapps/am.war] has finished
```

---

### Access AM Console

Open browser:
```
http://localhost:8081/am
```

You should see the **AM Configuration** page.

---

## Step 6: Configure PingAM

### Configuration Options

You have two choices:

1. **Interactive Configuration** (GUI) - Recommended for learning
2. **File-Based Configuration** (Automated) - For production/DevOps

---

### Option A: Interactive Configuration (Recommended)

#### Step 1: Initial Page

Navigate to: `http://localhost:8081/am`

Select: **Create Default Configuration** or **Custom Configuration**

We'll use **Custom Configuration** to connect to our PingDS instance.

---

#### Step 2: General Configuration

| Field | Value |
|-------|-------|
| **Default User Password** | `Passw0rd123` |
| **amAdmin Password** | `Passw0rd123` |
| **Agent Password** | `Passw0rd123` |

---

#### Step 3: Server Settings

| Field | Value |
|-------|-------|
| **Server URL** | `http://pingam:8080/am` |
| **Cookie Domain** | `.example.com` |
| **Platform Locale** | `en_US` |
| **Configuration Directory** | `/opt/am-config` |

---

#### Step 4: Configuration Store

| Field | Value |
|-------|-------|
| **Configuration Store Type** | `External DS Repository` |
| **Server Name** | `pingds` |
| **Port** | `1636` |
| **SSL/TLS** | ✅ Enabled |
| **Root Suffix** | `ou=am-config` |
| **Login ID** | `uid=am-config,ou=admins,ou=am-config` |
| **Password** | `AMConfig@2024` |

---

#### Step 5: User Store

| Field | Value |
|-------|-------|
| **User Store Type** | `External DS Repository` |
| **Server Name** | `pingds` |
| **Port** | `1636` |
| **SSL/TLS** | ✅ Enabled |
| **Root Suffix** | `ou=identities` |
| **Login ID** | `uid=am-identity-bind-account,ou=admins,ou=identities` |
| **Password** | `AMIdentity@2024` |

---

#### Step 6: Site Configuration

| Field | Value |
|-------|-------|
| **Site Name** | `ForgeRock-Site1` (or leave default) |
| **Load Balancer URL** | Leave empty for single server |

---

#### Step 7: Complete Installation

Click **Create Configuration**

Wait for configuration to complete (2-5 minutes).

---

### Option B: File-Based Configuration (Automated)

Update docker-compose environment variables:

```yaml
environment:
  # Enable FBC
  - com.sun.identity.sm.sms_object_filebased_enabled=true
  - com.sun.identity.configuration.directory=/opt/am-config

  # Server settings
  - am.server.fqdn=pingam
  - am.server.port=8080
  - am.server.protocol=http

  # User store (identity repository)
  - am.stores.user.type=LDAPv3ForOpenDS
  - am.stores.user.servers=pingds:1636
  - am.stores.user.ssl.enabled=true
  - am.stores.user.username=uid=am-identity-bind-account,ou=admins,ou=identities
  - am.stores.user.password=AMIdentity@2024
  - am.stores.user.basedn=ou=identities

  # CTS store
  - am.stores.cts.servers=pingds:1636
  - am.stores.cts.username=uid=openam_cts,ou=admins,ou=famrecords,ou=openam-session,ou=tokens
  - am.stores.cts.password=AMCTS@2024
  - am.stores.cts.ssl.enabled=true

  # Config store
  - am.stores.application.servers=pingds:1636
  - am.stores.application.username=uid=am-config,ou=admins,ou=am-config
  - am.stores.application.password=AMConfig@2024
  - am.stores.application.ssl.enabled=true
```

---

## Step 7: Verify Installation

### Login to AM Console

1. Navigate to: `http://localhost:8081/am/console`
2. Username: `amAdmin`
3. Password: `Passw0rd123` (or what you set)

---

### Verify Data Stores

In AM Console:

1. Navigate: **Realms** → **Top Level Realm** → **Data Stores**
2. You should see:
   - `embedded` (default - can ignore)
   - User Data Store (connected to `ou=identities`)

3. Click on User Data Store
4. Click **Test Connection** - Should succeed

---

### Verify Users

1. Navigate: **Realms** → **Top Level Realm** → **Subjects**
2. Search for: `jdoe`
3. You should see John Doe from your PingDS user store!

---

### Test Authentication

Create a simple authentication test:

```bash
# Test authentication with curl
curl -X POST \
  'http://localhost:8081/am/json/authenticate' \
  -H 'Content-Type: application/json' \
  -H 'X-OpenAM-Username: jdoe' \
  -H 'X-OpenAM-Password: TestUser@2024' \
  -H 'Accept-API-Version: resource=2.0, protocol=1.0'
```

Should return a token response if successful!

---

## Troubleshooting

### Issue 1: AM Won't Start

**Symptom:** Container restarts continuously

**Check logs:**
```bash
docker logs pingam
```

**Common causes:**
- Insufficient memory (increase to 2GB+)
- WAR file missing or corrupted
- Port conflict (8080 already in use)

**Solution:**
```bash
# Check resources
docker stats pingam

# Rebuild with clean state
docker-compose down
docker-compose up -d --build pingam
```

---

### Issue 2: Cannot Connect to PingDS

**Symptom:** Configuration fails with LDAP connection error

**Verify PingDS is accessible:**
```bash
# From AM container
docker exec pingam ping -c 3 pingds
docker exec pingam nc -zv pingds 1636
```

**Check certificates:**
```bash
# Export DS cert
docker exec pingds /opt/opendj/bin/dskeymgr export-ca-cert \
  --deploymentId forgerock-eval \
  --deploymentIdPassword Passw0rd123 \
  --outputFile /tmp/ds-ca-cert.pem

# Copy to shared volume
docker cp pingds:/tmp/ds-ca-cert.pem ./shared-certs/

# Import into AM truststore
docker exec pingam keytool -importcert \
  -file /opt/certs/ds-ca-cert.pem \
  -alias pingds-ca \
  -keystore /usr/local/tomcat/conf/keystores/truststore.jks \
  -storepass changeit \
  -noprompt
```

---

### Issue 3: User Authentication Fails

**Symptom:** Users from PingDS cannot login

**Check service account:**
```bash
# Test identity bind account
docker exec pingds /opt/opendj/bin/ldapsearch \
  --hostname pingds --port 1636 --useSSL --trustAll \
  --bindDN "uid=am-identity-bind-account,ou=admins,ou=identities" \
  --bindPassword "AMIdentity@2024" \
  --baseDN "ou=identities" \
  "(uid=jdoe)" dn
```

**Check user exists:**
```bash
docker exec pingds /opt/opendj/bin/ldapsearch \
  --hostname pingds --port 1636 --useSSL --trustAll \
  --bindDN "cn=Directory Manager" \
  --bindPassword "Passw0rd123" \
  --baseDN "ou=identities" \
  "(uid=jdoe)" \
  dn cn userPassword
```

---

### Issue 4: Health Check Failing

**Symptom:** Container shows "unhealthy" status

**Check health endpoint:**
```bash
docker exec pingam curl -f http://localhost:8080/am/isAlive.jsp
```

**Should return:** HTTP 200 with "true"

---

## Post-Installation Steps

### 1. Secure the Installation

- [ ] Change default `amAdmin` password
- [ ] Change service account passwords
- [ ] Configure HTTPS (port 8443)
- [ ] Restrict access to admin console

---

### 2. Configure Authentication

- [ ] Create authentication trees
- [ ] Configure MFA
- [ ] Set up social login
- [ ] Configure session timeouts

---

### 3. Set Up Applications

- [ ] Register OAuth 2.0 clients
- [ ] Configure SAML service providers
- [ ] Set up policy sets
- [ ] Define resource types

---

## Quick Command Reference

```bash
# Start services
docker-compose up -d

# View AM logs
docker logs -f pingam
docker logs --tail 100 pingam

# Restart AM
docker restart pingam

# Enter AM container
docker exec -it pingam bash

# Check AM version
docker exec pingam curl -s http://localhost:8080/am/json/serverinfo/version

# Stop services
docker-compose down
```

---

## Next Steps

1. ✅ PingAM installed and configured
2. → Explore AM Console (Realms, Services, Authentication)
3. → Create authentication trees
4. → Test SSO with sample application
5. → Configure OAuth 2.0 / OpenID Connect

---

## Summary

You now have:
- ✅ PingAM container running on Tomcat
- ✅ Connected to PingDS for all data stores
- ✅ Access to AM admin console
- ✅ User authentication working
- ✅ Ready for application integration

**Congratulations!** You have a working PingAM + PingDS environment! 🎉
