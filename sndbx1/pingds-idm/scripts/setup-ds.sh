#!/bin/bash
set -euo pipefail

# Setup PingDS with IDM repository profile
# This DS instance is dedicated to PingIDM's internal data

PINGDS_HOME=${PINGDS_HOME:-/opt/opendj}
DATA_DIR=${DATA_DIR:-/opt/pingds-data}

DS_HOSTNAME=${DS_HOSTNAME:-pingds-idm}
DS_SERVER_ID=${DS_SERVER_ID:-ds-idm-01}
DS_DEPLOYMENT_PASSWORD=${DS_DEPLOYMENT_PASSWORD:-Passw0rd123}
DS_ROOT_PASSWORD=${DS_ROOT_PASSWORD:-Passw0rd123}
DS_MONITOR_PASSWORD=${DS_MONITOR_PASSWORD:-Passw0rd123}

log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

is_ds_configured() {
    [ -f "${DATA_DIR}/.setup_complete" ] && \
    [ -d "${PINGDS_HOME}/db" ] && \
    [ -f "${PINGDS_HOME}/config/config.ldif" ]
}

main() {
    log_info "Starting PingDS (IDM Repo) setup process..."

    if is_ds_configured; then
        log_info "PingDS-IDM already configured. Skipping setup."
        return 0
    fi

    log_info "First-time setup detected. Configuring PingDS for IDM repository..."

    # Generate deployment ID
    log_info "Generating deployment ID..."
    DS_DEPLOYMENT_ID=$(${PINGDS_HOME}/bin/dskeymgr create-deployment-id \
        --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}")
    echo "${DS_DEPLOYMENT_ID}" > "${DATA_DIR}/.deployment_id"
    chmod 600 "${DATA_DIR}/.deployment_id"
    log_success "Deployment ID generated"

    # Setup DS with IDM repo profile
    # Uses different ports to avoid conflict with AM's DS
    log_info "Running DS setup with idm-repo:8.0 profile..."
    ${PINGDS_HOME}/setup \
        --serverId "${DS_SERVER_ID}" \
        --deploymentId "${DS_DEPLOYMENT_ID}" \
        --deploymentIdPassword "${DS_DEPLOYMENT_PASSWORD}" \
        --rootUserDn "cn=Directory Manager" \
        --rootUserPassword "${DS_ROOT_PASSWORD}" \
        --monitorUserPassword "${DS_MONITOR_PASSWORD}" \
        --hostname "${DS_HOSTNAME}" \
        --ldapPort 2389 \
        --ldapsPort 2636 \
        --adminConnectorPort 5444 \
        --httpPort 9080 \
        --httpsPort 9443 \
        --profile idm-repo:8.0 \
        --set idm-repo/domain:forgerock.com \
        --acceptLicense

    log_success "DS setup completed with IDM repo profile"

    log_info "=========================================="
    log_info "PingDS-IDM Configuration Summary"
    log_info "=========================================="
    log_info "Hostname:    ${DS_HOSTNAME}"
    log_info "LDAP Port:   2389"
    log_info "LDAPS Port:  2636"
    log_info "Admin Port:  5444"
    log_info "Profile:     idm-repo:8.0"
    log_info "Base DN:     dc=openidm,dc=forgerock,dc=com"
    log_info "Root DN:     cn=Directory Manager"
    log_info "=========================================="

    touch "${DATA_DIR}/.setup_complete"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "${DATA_DIR}/.setup_timestamp"
    log_success "PingDS-IDM first-time setup completed!"
}

main "$@"
