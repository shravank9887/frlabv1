#!/bin/bash
set -e

PINGDS_HOME=${PINGDS_HOME:-/opt/opendj}
DATA_DIR=${DATA_DIR:-/opt/pingds-data}

log_info() { echo "[ENTRYPOINT] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo "[ENTRYPOINT] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >&2; }

# Fix permissions if running as root
if [ "$(id -u)" = "0" ]; then
    log_info "Running as root - fixing volume permissions..."
    chown -R pingds:pingds /opt/pingds-data /opt/certs 2>/dev/null || true
    chmod 755 /opt/certs
    log_info "Switching to pingds user..."
    exec gosu pingds "$0" "$@"
fi

# Check if setup needed
is_ds_configured() {
    [ -f "${DATA_DIR}/.setup_complete" ] && \
    [ -d "${PINGDS_HOME}/db" ] && \
    [ -f "${PINGDS_HOME}/config/config.ldif" ]
}

FIRST_TIME_SETUP=false
if ! is_ds_configured; then
    log_info "DS instance not found. Running setup..."
    /opt/scripts/setup-ds.sh
    FIRST_TIME_SETUP=true
else
    log_info "DS-IDM already configured. Skipping setup."
fi

case "${1:-start-server}" in
    start-server)
        log_info "Starting PingDS-IDM server..."
        log_info "  LDAP:  port 2389"
        log_info "  LDAPS: port 2636"
        log_info "  Admin: port 5444"

        # Export certificates after server starts (background task)
        # Runs on first setup OR if cert files are missing (e.g. volume was deleted)
        CERTS_DIR=${CERTS_DIR:-/opt/certs}

        # RACE CONDITION FIX: On fresh setup, delete stale certs BEFORE starting server.
        # Without this, IDM may find old cert files on the shared volume, import them,
        # then fail because DS generated a new deployment key (new CA cert).
        # By deleting first, IDM's wait loop correctly blocks until the new cert is written.
        if [ "$FIRST_TIME_SETUP" = "true" ]; then
            log_info "Fresh setup — clearing stale certificates from shared volume..."
            rm -f "${CERTS_DIR}/ds-idm-ca-cert.pem" \
                  "${CERTS_DIR}/idm-truststore.jks" \
                  "${CERTS_DIR}/idm-truststore.p12" \
                  "${CERTS_DIR}/idm-storepass" 2>/dev/null || true
        fi

        if [ "$FIRST_TIME_SETUP" = "true" ] || [ ! -f "${CERTS_DIR}/ds-idm-ca-cert.pem" ]; then
            (
                log_info "Waiting for server to be ready before exporting certificates..."
                MAX_WAIT=120
                WAIT_COUNT=0

                while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
                    if ${PINGDS_HOME}/bin/status \
                        --hostname "${DS_HOSTNAME:-pingds-idm}" \
                        --port 5444 \
                        --bindDN "cn=Directory Manager" \
                        --bindPassword "${DS_ROOT_PASSWORD:-Passw0rd123}" \
                        --trustAll > /dev/null 2>&1; then

                        log_info "Server is ready! Exporting certificates..."
                        /opt/scripts/export-certificates.sh
                        exit 0
                    fi
                    sleep 3
                    WAIT_COUNT=$((WAIT_COUNT + 3))
                done

                log_error "Server did not become ready within ${MAX_WAIT}s. Certificate export skipped."
            ) &
        else
            log_info "Certificates already exist in ${CERTS_DIR}. Skipping export."
        fi

        exec ${PINGDS_HOME}/bin/start-ds --nodetach
        ;;
    *)
        exec "$@"
        ;;
esac
