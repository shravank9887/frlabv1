#!/bin/bash
set -euo pipefail

# Script to setup PingDS with three profiles for AM integration
# This script runs once during initial container setup

PINGDS_HOME=${PINGDS_HOME:-/opt/opendj}
DATA_DIR=${DATA_DIR:-/opt/pingds-data}
CERTS_DIR=${CERTS_DIR:-/opt/certs}
BACKUP_DIR=${BACKUP_DIR:-/opt/backups}

# Environment variables with defaults
DS_HOSTNAME=${DS_HOSTNAME:-pingds}
DS_SERVER_ID=${DS_SERVER_ID:-ds-server-01}
DS_DEPLOYMENT_ID=${DS_DEPLOYMENT_ID:-forgerock-eval}
DS_DEPLOYMENT_PASSWORD=${DS_DEPLOYMENT_PASSWORD:-Passw0rd123}
DS_ROOT_PASSWORD=${DS_ROOT_PASSWORD:-Passw0rd123}
DS_MONITOR_PASSWORD=${DS_MONITOR_PASSWORD:-Passw0rd123}
AM_CONFIG_PASSWORD=${AM_CONFIG_PASSWORD:-Passw0rd123}
AM_IDENTITY_PASSWORD=${AM_IDENTITY_PASSWORD:-Passw0rd123}

# Logging functions
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check if DS is already configured
is_ds_configured() {
    # Check multiple indicators that DS is configured
    if [ -f "${DATA_DIR}/.setup_complete" ] && \
       [ -d "${PINGDS_HOME}/db" ] && \
       [ -f "${PINGDS_HOME}/config/config.ldif" ]; then
        return 0  # True - DS is configured
    else
        return 1  # False - DS needs setup
    fi
}

# Function to generate deployment ID
generate_deployment_id() {
    log_info "Generating deployment ID..."
    
    GENERATED_ID=$(${PINGDS_HOME}/bin/dskeymgr create-deployment-id --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}")
    
    if [ -z "${GENERATED_ID}" ]; then
        log_error "Failed to generate deployment ID"
        return 1
    fi
    
    # Store it for setup to use
    export DS_DEPLOYMENT_ID="${GENERATED_ID}"

    # Persist deployment ID for later use (certificate export after server starts)
    echo "${GENERATED_ID}" > "${DATA_DIR}/.deployment_id"
    chmod 600 "${DATA_DIR}/.deployment_id"

    log_success "Deployment ID generated and saved: ${DS_DEPLOYMENT_ID}"
}

# Function to setup PingDS with three AM profiles
setup_pingds() {
    log_info "Starting PingDS setup with AM profiles..."
    log_info "Hostname: ${DS_HOSTNAME}"
    log_info "Server ID: ${DS_SERVER_ID}"
    
    ${PINGDS_HOME}/setup \
        --serverId "${DS_SERVER_ID}" \
        --deploymentId "${DS_DEPLOYMENT_ID}" \
        --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}" \
        --rootUserDn "cn=Directory Manager" \
        --rootUserPassword "${DS_ROOT_PASSWORD}" \
        --monitorUserPassword "${DS_MONITOR_PASSWORD}" \
        --hostname "${DS_HOSTNAME}" \
        --ldapPort 1389 \
        --ldapsPort 1636 \
        --adminConnectorPort 4444 \
        --httpPort 8080 \
        --httpsPort 8443 \
        --profile am-config:6.5 \
        --set am-config/amConfigAdminPassword:"${AM_CONFIG_PASSWORD}" \
        --profile am-identity-store:8.0 \
        --set am-identity-store/amIdentityStoreAdminPassword:"${AM_IDENTITY_PASSWORD}" \
        --profile am-cts:6.5 \
        --set am-cts/amCtsAdminPassword:Password123 \
        --acceptLicense
    
    log_success "PingDS setup completed"
}

# Function to export certificate and create truststore for AM
# NOTE: This function is called from docker-entrypoint.sh AFTER server is running
export_truststore() {
    log_info "Exporting certificate and creating PKCS12 truststore for AM..."

    # Export CA certificate with deployment credentials
    if ${PINGDS_HOME}/bin/dskeymgr export-ca-cert \
        --deploymentId "${DS_DEPLOYMENT_ID}" \
        --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}" \
        --outputFile "${CERTS_DIR}/ds-ca-cert.pem" 2>/dev/null; then

        log_success "Certificate exported to: ${CERTS_DIR}/ds-ca-cert.pem"

        # Create PKCS12 truststore for AM
        if keytool -import \
            -noprompt \
            -trustcacerts \
            -alias pingds-ca \
            -file "${CERTS_DIR}/ds-ca-cert.pem" \
            -keystore "${CERTS_DIR}/truststore.p12" \
            -storetype PKCS12 \
            -storepass changeit 2>/dev/null; then

            # Set proper permissions to make it readable
            chmod 644 "${CERTS_DIR}/ds-ca-cert.pem" 2>/dev/null || true
            chmod 644 "${CERTS_DIR}/truststore.p12" 2>/dev/null || true

            log_success "Truststore created successfully"
            log_info "Truststore location: ${CERTS_DIR}/truststore.p12"
            log_info "Certificate location: ${CERTS_DIR}/ds-ca-cert.pem"
            log_info "Truststore password: changeit"
            log_info ""
            log_info "To make accessible to AM container:"
            log_info "  1. Mount ${CERTS_DIR} as a shared volume"
            log_info "  2. Reference in AM: /path/to/shared/truststore.p12"
        else
            log_error "Failed to create PKCS12 truststore"
            log_info "You can create the truststore manually after setup"
        fi
    else
        log_error "Failed to export CA certificate using dskeymgr"
        log_info "Certificate export skipped - you can export manually after setup"
        log_info "The PingDS server will still function normally"
    fi

    # Always return success - don't fail the entire setup for truststore issues
    return 0
}

# Function to display DS configuration info
display_info() {
    log_info "=========================================="
    log_info "PingDS Configuration Summary"
    log_info "=========================================="
    log_info "Hostname:          ${DS_HOSTNAME}"
    log_info "LDAP Port:         1389"
    log_info "LDAPS Port:        1636"
    log_info "Admin Port:        4444"
    log_info "HTTP Port:         8080"
    log_info "HTTPS Port:        8443"
    log_info "Root DN:           cn=Directory Manager"
    log_info "Base DNs:"
    log_info "  - AM Config:     ou=am-config"
    log_info "  - CTS:           ou=tokens"
    log_info "  - Identities:    ou=identities"
    log_info "=========================================="
    log_info "For AM Integration:"
    log_info "  - Config Store Admin:   uid=am-config,ou=admins,ou=am-config"
    log_info "  - Identity Store Admin: uid=am-identity-bind-account,ou=admins,ou=identities"
    log_info "  - CTS Admin:           uid=openam_cts,ou=admins,ou=famrecords,ou=openam-session,ou=tokens"
    log_info "=========================================="
}

# Function to verify DS is running (if it was started during setup)
verify_ds() {
    log_info "Verifying DS configuration..."
    
    # Just check if config files exist, don't try to connect
    # (server might not be running yet)
    if [ -f "${PINGDS_HOME}/config/config.ldif" ]; then
        log_success "DS configuration files are present"
    else
        log_error "DS configuration files are missing!"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting PingDS setup process..."
    
    # Check if already setup
    if is_ds_configured; then
        log_info "=========================================="
        log_info "PingDS is already configured"
        log_info "=========================================="
        
        # Read setup timestamp if available
        if [ -f "${DATA_DIR}/.setup_timestamp" ]; then
            setup_time=$(cat "${DATA_DIR}/.setup_timestamp")
            log_info "Original setup completed at: ${setup_time}"
        fi
        
        log_info "Skipping setup - will proceed to start server"
        log_info "=========================================="
        
        # Display info even on restart
        display_info
        
        return 0
    fi
    
    log_info "First-time setup detected. Configuring PingDS..."

    # Step 1: Generate deployment ID
    generate_deployment_id

    # Step 2: Setup DS with AM profiles (this creates certificates automatically)
    setup_pingds

    # Step 3: Verify DS configuration
    verify_ds

    # Step 4: Display configuration info
    display_info

    # NOTE: Certificate export moved to docker-entrypoint.sh (runs after server starts)
    
    # Mark setup as complete
    touch "${DATA_DIR}/.setup_complete"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "${DATA_DIR}/.setup_timestamp"
    
    log_success "PingDS first-time setup completed successfully!"
}

# Run main function
main "$@"