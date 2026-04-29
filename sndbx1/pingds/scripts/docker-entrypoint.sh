#!/bin/bash
set -e

PINGDS_HOME=${PINGDS_HOME:-/opt/opendj}
DATA_DIR=${DATA_DIR:-/opt/pingds-data}

# Logging function
log_info() {
    echo "[ENTRYPOINT] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ENTRYPOINT] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >&2
}

# Fix volume permissions if running as root (Docker volume mounts override Dockerfile ownership)
if [ "$(id -u)" = "0" ]; then
    log_info "Running as root - fixing volume permissions..."

    # Fix ownership of volume-mounted directories
    chown -R pingds:pingds /opt/pingds-data /opt/certs /opt/backups /opt/logs 2>/dev/null || true

    # Ensure correct permissions
    chmod 755 /opt/certs

    log_info "Permissions fixed. Switching to pingds user..."

    # Re-execute this script as pingds user
    exec gosu pingds "$0" "$@"
fi

# From this point forward, we're running as pingds user

# Function to check if DS instance exists and is configured
is_ds_instance_valid() {
    if [ -d "${PINGDS_HOME}/db" ] && \
       [ -f "${PINGDS_HOME}/config/config.ldif" ] && \
       [ -f "${DATA_DIR}/.setup_complete" ]; then
        return 0
    else
        return 1
    fi
}

# Run setup if this is first start OR if instance is corrupted
FIRST_TIME_SETUP=false
if ! is_ds_instance_valid; then
    log_info "DS instance not found or incomplete. Running setup script..."
    /opt/scripts/setup-ds.sh

    # Verify setup was successful
    if ! is_ds_instance_valid; then
        log_error "Setup failed! DS instance is still invalid."
        exit 1
    fi

    FIRST_TIME_SETUP=true
else
    log_info "DS instance already configured. Skipping setup."

    # Optionally run setup script just to display info
    /opt/scripts/setup-ds.sh || true
fi

# Export certificates after first-time setup
# This runs AFTER server starts and is verified to be running
if [ "$FIRST_TIME_SETUP" = "true" ]; then
    log_info "First-time setup completed. Certificates will be exported after server starts."
fi

# Handle different commands
case "${1:-start-server}" in
    start-server)
        log_info "Starting PingDS server..."
        log_info "Server will listen on:"
        log_info "  - LDAP:  port 1389"
        log_info "  - LDAPS: port 1636"
        log_info "  - Admin: port 4444"
        log_info "  - HTTP:  port 8080"
        log_info "  - HTTPS: port 8443"

        # If first-time setup, start a background process to export certificates
        # once the server is ready
        if [ "$FIRST_TIME_SETUP" = "true" ]; then
            log_info "First-time setup: will export certificates once server is ready"

            # Background script to wait for server and export certificates
            (
                log_info "Waiting for server to be ready before exporting certificates..."
                MAX_WAIT=120
                WAIT_COUNT=0

                while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
                    if ${PINGDS_HOME}/bin/status \
                        --hostname "${DS_HOSTNAME:-pingds}" \
                        --port 4444 \
                        --bindDN "cn=Directory Manager" \
                        --bindPassword "${DS_ROOT_PASSWORD}" \
                        --trustAll > /dev/null 2>&1; then

                        log_info "Server is ready! Exporting certificates..."
                        /opt/scripts/export-certificates.sh
                        exit 0
                    fi
                    sleep 3
                    WAIT_COUNT=$((WAIT_COUNT + 3))
                done

                log_error "Server did not become ready within ${MAX_WAIT} seconds. Certificate export skipped."
            ) &
        fi

        # Start DS in foreground (no detach for Docker)
        exec ${PINGDS_HOME}/bin/start-ds --nodetach
        ;;
    
    stop-server)
        log_info "Stopping PingDS server..."
        ${PINGDS_HOME}/bin/stop-ds
        ;;
    
    restart-server)
        log_info "Restarting PingDS server..."
        ${PINGDS_HOME}/bin/stop-ds
        sleep 2
        exec ${PINGDS_HOME}/bin/start-ds --nodetach
        ;;
    
    status)
        log_info "Checking DS status..."
        ${PINGDS_HOME}/bin/status \
            --hostname "${DS_HOSTNAME:-pingds}" \
            --port 4444 \
            --bindDN "cn=Directory Manager" \
            --bindPassword "${DS_ROOT_PASSWORD}" \
            --trustAll
        ;;
    
    verify)
        log_info "Verifying DS configuration..."
        if is_ds_instance_valid; then
            log_info "DS instance is valid and ready"
            exit 0
        else
            log_error "DS instance is invalid or incomplete"
            exit 1
        fi
        ;;
    
    shell|bash)
        log_info "Starting interactive shell..."
        exec /bin/bash
        ;;
    
    *)
        log_info "Executing custom command: $@"
        exec "$@"
        ;;
esac
