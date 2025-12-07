# Certificate Export Changes Summary

## Overview
Modified the PingDS setup to ensure certificate export happens AFTER the DS server is up and running, using the correct deployment ID and password credentials.

## Changes Made

### 1. **setup-ds.sh** - Persist Deployment ID & Update Export Function

#### Change 1: Persist Generated Deployment ID (Lines 61-63)
```bash
# Persist deployment ID for later use (certificate export after server starts)
echo "${GENERATED_ID}" > "${DATA_DIR}/.deployment_id"
chmod 600 "${DATA_DIR}/.deployment_id"
```
**Why**: The deployment ID is generated during setup and needs to be available later for certificate export.

#### Change 2: Update export_truststore Function (Lines 99-103)
```bash
# Export CA certificate with deployment credentials
if ${PINGDS_HOME}/bin/dskeymgr export-ca-cert \
    --deploymentId "${DS_DEPLOYMENT_ID}" \
    --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}" \
    --outputFile "${CERTS_DIR}/ds-ca-cert.pem" 2>/dev/null; then
```
**Why**: Use the proper deployment credentials for certificate export (was missing before).

#### Change 3: Remove Certificate Export from Setup Main Function (Line 220)
Removed the call to `export_truststore` from the setup process because:
- Server is not running yet during setup
- Certificate export needs to happen AFTER server verification
- Moved to docker-entrypoint.sh with server verification

---

### 2. **docker-entrypoint.sh** - Certificate Export After Server Verification

#### Change 1: Track First-Time Setup (Lines 28, 39)
```bash
FIRST_TIME_SETUP=false
# ... set to true after first setup completes
FIRST_TIME_SETUP=true
```
**Why**: Need to know when to trigger certificate export.

#### Change 2: Background Certificate Export Process (Lines 66-90)
```bash
if [ "$FIRST_TIME_SETUP" = "true" ]; then
    log_info "First-time setup: will export certificates once server is ready"

    # Background script to wait for server and export certificates
    (
        # Wait up to 120 seconds for server to be ready
        # Check server status every 3 seconds
        # Once ready, call export-certificates.sh
    ) &
fi
```
**Why**: Server starts in foreground (blocking), so we need a background process to:
1. Wait for server to be ready
2. Verify server is responding
3. Export certificates using the saved deployment ID

---

### 3. **export-certificates.sh** - New Helper Script

**Purpose**: Dedicated script to export CA certificate and create truststore AFTER server verification.

**Key Features**:
- Reads persisted deployment ID from `${DATA_DIR}/.deployment_id`
- Verifies DS server is running before export
- Uses deployment credentials: `--deploymentId` and `--deploymentIdPassword`
- Exports certificate to: `${CERTS_DIR}/ds-ca-cert.pem`
- Creates PKCS12 truststore: `${CERTS_DIR}/truststore.p12`
- Idempotent: Skips export if certificates already exist
- Detailed logging for troubleshooting

**Location**: `/opt/scripts/export-certificates.sh` (in container)

---

## Execution Flow

### First-Time Setup
1. `docker-entrypoint.sh` runs
2. Detects no valid DS instance → runs `setup-ds.sh`
3. `setup-ds.sh`:
   - Generates deployment ID
   - **Saves deployment ID to file**: `${DATA_DIR}/.deployment_id`
   - Runs DS setup command
   - **Does NOT export certificates** (server not running yet)
4. `docker-entrypoint.sh` sets `FIRST_TIME_SETUP=true`
5. Starts **background process** to monitor server and export certs
6. Starts DS server in **foreground** (main process)
7. **Background process**:
   - Waits for server to be ready (max 120 seconds)
   - Verifies server responds to status command
   - Calls `export-certificates.sh`
8. `export-certificates.sh`:
   - Reads deployment ID from saved file
   - Exports CA certificate using deployment credentials
   - Creates PKCS12 truststore

### Subsequent Starts
1. `docker-entrypoint.sh` runs
2. Detects valid DS instance → skips setup
3. `FIRST_TIME_SETUP=false`
4. Starts DS server normally
5. No certificate export (already done)

---

## Using the Environment Variables

The deployment credentials come from `docker-compose.yaml`:

```yaml
environment:
  - DS_DEPLOYMENT_ID=forgerock-eval          # Used as base name
  - DS_DEPLOYMENT_PASSWORD=Passw0rd123      # Used to create and export
```

**Note**: The actual deployment ID is **auto-generated** during setup and saved. The `DS_DEPLOYMENT_ID` from docker-compose is overwritten by the generated ID.

---

## Manual Certificate Export

If you need to manually export the certificate later:

```bash
# Enter the container
docker exec -it pingds bash

# Run the export script
/opt/scripts/export-certificates.sh

# Or use dskeymgr directly
DEPLOYMENT_ID=$(cat /opt/pingds-data/.deployment_id)
/opt/opendj/bin/dskeymgr export-ca-cert \
    --deploymentId "${DEPLOYMENT_ID}" \
    --deploymentIdPassword "Passw0rd123" \
    --outputFile /opt/certs/ds-ca-cert.pem
```

---

## Files Modified

1. **pingds/scripts/setup-ds.sh**
   - Added deployment ID persistence
   - Updated export_truststore function with credentials
   - Removed certificate export from main setup flow

2. **pingds/scripts/docker-entrypoint.sh**
   - Added first-time setup tracking
   - Added background certificate export process
   - Ensures server is ready before export

3. **pingds/scripts/export-certificates.sh** (NEW)
   - Dedicated certificate export script
   - Server verification
   - Reads saved deployment ID
   - Creates both PEM cert and PKCS12 truststore

---

## Verification

After container starts for the first time, verify certificates were exported:

```bash
# Check if certificates exist
docker exec pingds ls -la /opt/certs/

# Expected output:
# -rw-r--r-- 1 pingds pingds   1234 Dec  6 10:00 ds-ca-cert.pem
# -rw-r--r-- 1 pingds pingds   5678 Dec  6 10:00 truststore.p12

# View certificate details
docker exec pingds openssl x509 -in /opt/certs/ds-ca-cert.pem -text -noout

# Verify truststore
docker exec pingds keytool -list \
    -keystore /opt/certs/truststore.p12 \
    -storetype PKCS12 \
    -storepass changeit
```

---

## Troubleshooting

### Certificate export failed
Check the logs:
```bash
docker logs pingds | grep CERT-EXPORT
```

### Deployment ID not found
Check if the file exists:
```bash
docker exec pingds cat /opt/pingds-data/.deployment_id
```

### Server not ready in time
Increase `MAX_WAIT` in docker-entrypoint.sh (line 72) from 120 to a higher value.

---

## Summary

✅ Deployment ID is persisted to a file during setup
✅ Certificate export uses correct deployment credentials
✅ Export only happens AFTER server is verified to be running
✅ Background process handles the timing automatically
✅ Idempotent - won't re-export if certificates already exist
✅ Non-blocking - server starts normally while export happens in background
