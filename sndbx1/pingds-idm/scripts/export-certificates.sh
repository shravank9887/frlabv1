#!/bin/bash
# Export DS-IDM CA certificate for PingIDM truststore consumption
# Called from docker-entrypoint.sh AFTER server is running

PINGDS_HOME=${PINGDS_HOME:-/opt/opendj}
DATA_DIR=${DATA_DIR:-/opt/pingds-data}
CERTS_DIR=${CERTS_DIR:-/opt/certs}
DS_DEPLOYMENT_PASSWORD=${DS_DEPLOYMENT_PASSWORD:-Passw0rd123}

log_info() { echo "[CERT-EXPORT] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo "[CERT-EXPORT] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >&2; }
log_success() { echo "[CERT-EXPORT] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# Read deployment ID from setup
if [ ! -f "${DATA_DIR}/.deployment_id" ]; then
    log_error "Deployment ID not found. Cannot export certificates."
    exit 1
fi
DS_DEPLOYMENT_ID=$(cat "${DATA_DIR}/.deployment_id")

log_info "Exporting CA certificate from DS-IDM..."

# Step 1: Export CA certificate in PEM format
if ${PINGDS_HOME}/bin/dskeymgr export-ca-cert \
    --deploymentId "${DS_DEPLOYMENT_ID}" \
    --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}" \
    --outputFile "${CERTS_DIR}/ds-idm-ca-cert.pem" 2>/dev/null; then

    log_success "CA cert exported: ${CERTS_DIR}/ds-idm-ca-cert.pem"
else
    log_error "Failed to export CA certificate"
    exit 1
fi

# Step 2: Create a JKS truststore for IDM consumption
# IDM's default truststore is JKS format at /opt/openidm/security/truststore
log_info "Creating JKS truststore for PingIDM..."

# Remove old truststore if exists
rm -f "${CERTS_DIR}/idm-truststore.jks"

if keytool -import \
    -noprompt \
    -trustcacerts \
    -alias ds-idm-ca \
    -file "${CERTS_DIR}/ds-idm-ca-cert.pem" \
    -keystore "${CERTS_DIR}/idm-truststore.jks" \
    -storetype JKS \
    -storepass changeit 2>/dev/null; then

    log_success "JKS truststore created: ${CERTS_DIR}/idm-truststore.jks"
    log_info "  Alias:    ds-idm-ca"
    log_info "  Type:     JKS"
    log_info "  Password: changeit"
else
    log_error "Failed to create JKS truststore"
    exit 1
fi

# Step 3: Also create PKCS12 truststore (for reference/alternative use)
rm -f "${CERTS_DIR}/idm-truststore.p12"

if keytool -import \
    -noprompt \
    -trustcacerts \
    -alias ds-idm-ca \
    -file "${CERTS_DIR}/ds-idm-ca-cert.pem" \
    -keystore "${CERTS_DIR}/idm-truststore.p12" \
    -storetype PKCS12 \
    -storepass changeit 2>/dev/null; then

    log_success "PKCS12 truststore created: ${CERTS_DIR}/idm-truststore.p12"
fi

# Set readable permissions for IDM container
chmod 644 "${CERTS_DIR}/ds-idm-ca-cert.pem" 2>/dev/null || true
chmod 644 "${CERTS_DIR}/idm-truststore.jks" 2>/dev/null || true
chmod 644 "${CERTS_DIR}/idm-truststore.p12" 2>/dev/null || true

# Write storepass file (IDM reads password from this file)
echo -n "changeit" > "${CERTS_DIR}/idm-storepass"
chmod 644 "${CERTS_DIR}/idm-storepass" 2>/dev/null || true

log_success "Certificate export complete. Files in ${CERTS_DIR}/:"
ls -la "${CERTS_DIR}/"
