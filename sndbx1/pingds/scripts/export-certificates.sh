#!/bin/bash
set -e

# Script to export CA certificate and create truststore AFTER DS server is running
# This script is called from docker-entrypoint.sh

PINGDS_HOME=${PINGDS_HOME:-/opt/opendj}
DATA_DIR=${DATA_DIR:-/opt/pingds-data}
CERTS_DIR=${CERTS_DIR:-/opt/certs}
DS_HOSTNAME=${DS_HOSTNAME:-pingds}
DS_ROOT_PASSWORD=${DS_ROOT_PASSWORD:-Passw0rd123}
DS_DEPLOYMENT_PASSWORD=${DS_DEPLOYMENT_PASSWORD:-Passw0rd123}

# Logging functions
log_info() {
    echo "[CERT-EXPORT] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[CERT-EXPORT] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >&2
}

log_success() {
    echo "[CERT-EXPORT] $(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1"
}

# Check if certificates already exist
if [ -f "${CERTS_DIR}/ds-ca-cert.pem" ] && [ -f "${CERTS_DIR}/truststore.p12" ]; then
    log_info "Certificates already exist. Skipping export."
    exit 0
fi

# Read the persisted deployment ID
if [ ! -f "${DATA_DIR}/.deployment_id" ]; then
    log_error "Deployment ID file not found at ${DATA_DIR}/.deployment_id"
    log_error "Server may not be properly configured. Certificate export skipped."
    exit 1
fi

DS_DEPLOYMENT_ID=$(cat "${DATA_DIR}/.deployment_id")

if [ -z "${DS_DEPLOYMENT_ID}" ]; then
    log_error "Deployment ID is empty"
    exit 1
fi

log_info "Starting certificate export process..."
log_info "Deployment ID: ${DS_DEPLOYMENT_ID}"

# Verify DS server is running
log_info "Verifying DS server is running..."
if ! ${PINGDS_HOME}/bin/status \
    --hostname "${DS_HOSTNAME}" \
    --port 4444 \
    --bindDN "cn=Directory Manager" \
    --bindPassword "${DS_ROOT_PASSWORD}" \
    --trustAll > /dev/null 2>&1; then
    log_error "DS server is not running. Cannot export certificates."
    exit 1
fi

log_success "DS server is running and accessible"

# Export CA certificate with deployment credentials
log_info "Exporting CA certificate..."
if ${PINGDS_HOME}/bin/dskeymgr export-ca-cert \
    --deploymentId "${DS_DEPLOYMENT_ID}" \
    --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}" \
    --outputFile "${CERTS_DIR}/ds-ca-cert.pem"; then

    log_success "Certificate exported to: ${CERTS_DIR}/ds-ca-cert.pem"

    # Create PKCS12 truststore for AM
    log_info "Creating PKCS12 truststore..."
    if keytool -import \
        -noprompt \
        -trustcacerts \
        -alias pingds-ca \
        -file "${CERTS_DIR}/ds-ca-cert.pem" \
        -keystore "${CERTS_DIR}/truststore.p12" \
        -storetype PKCS12 \
        -storepass changeit; then

        # Set proper permissions to make it readable
        chmod 644 "${CERTS_DIR}/ds-ca-cert.pem" 2>/dev/null || true
        chmod 644 "${CERTS_DIR}/truststore.p12" 2>/dev/null || true

        log_success "Truststore created successfully"
        log_info "=========================================="
        log_info "Certificate Export Summary"
        log_info "=========================================="
        log_info "Certificate: ${CERTS_DIR}/ds-ca-cert.pem"
        log_info "Truststore:  ${CERTS_DIR}/truststore.p12"
        log_info "Password:    changeit"
        log_info "=========================================="
    else
        log_error "Failed to create PKCS12 truststore"
        exit 1
    fi
else
    log_error "Failed to export CA certificate"
    log_error "Check deployment ID and password are correct"
    exit 1
fi

log_success "Certificate export completed successfully!"
