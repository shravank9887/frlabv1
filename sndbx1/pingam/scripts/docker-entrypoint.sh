#!/bin/bash
set -e

CATALINA_HOME=${CATALINA_HOME:-/usr/local/tomcat}
CATALINA_BASE=${CATALINA_BASE:-/usr/local/tomcat}
CERTS_DIR=${CERTS_DIR:-/opt/certs}
TRUSTSTORE_SOURCE="${CERTS_DIR}/truststore.p12"
TRUSTSTORE_DEST="${CATALINA_HOME}/conf/keystores/truststore.p12"
TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASSWORD:-changeit}

# Logging functions
log_info() {
    echo "[AM-ENTRYPOINT] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[AM-ENTRYPOINT] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >&2
}

log_success() {
    echo "[AM-ENTRYPOINT] $(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1"
}

# Function to wait for PingDS truststore to be available
wait_for_truststore() {
    log_info "Checking for PingDS truststore..."

    local max_wait=180  # Wait up to 3 minutes
    local wait_count=0

    while [ $wait_count -lt $max_wait ]; do
        if [ -f "${TRUSTSTORE_SOURCE}" ]; then
            log_success "PingDS truststore found at: ${TRUSTSTORE_SOURCE}"
            return 0
        fi

        if [ $wait_count -eq 0 ]; then
            log_info "Waiting for PingDS to export truststore..."
        fi

        sleep 5
        wait_count=$((wait_count + 5))

        # Log every 30 seconds
        if [ $((wait_count % 30)) -eq 0 ]; then
            log_info "Still waiting for truststore... (${wait_count}s elapsed)"
        fi
    done

    log_error "Truststore not found after ${max_wait} seconds"
    log_error "PingDS may not be ready or certificate export failed"
    log_info "Starting Tomcat anyway - LDAPS connections may fail"
    return 1
}

# Function to setup truststore for Tomcat
setup_truststore() {
    log_info "Setting up truststore for PingAM..."

    # Create keystores directory if it doesn't exist
    mkdir -p "${CATALINA_HOME}/conf/keystores"

    # Copy truststore from shared certs directory
    if [ -f "${TRUSTSTORE_SOURCE}" ]; then
        log_info "Copying truststore to Tomcat keystores directory..."
        cp "${TRUSTSTORE_SOURCE}" "${TRUSTSTORE_DEST}"
        chmod 644 "${TRUSTSTORE_DEST}"
        log_success "Truststore copied to: ${TRUSTSTORE_DEST}"

        # Verify the truststore
        log_info "Verifying truststore contents..."
        if keytool -list -keystore "${TRUSTSTORE_DEST}" \
            -storetype PKCS12 \
            -storepass "${TRUSTSTORE_PASSWORD}" > /dev/null 2>&1; then
            log_success "Truststore verification passed"
        else
            log_error "Truststore verification failed - may be corrupted"
        fi
    else
        log_error "Truststore source not found: ${TRUSTSTORE_SOURCE}"
        return 1
    fi
}

# Function to configure Tomcat to use the truststore
configure_tomcat_truststore() {
    log_info "Configuring Tomcat to use PingDS truststore..."

    local setenv_file="${CATALINA_BASE}/bin/setenv.sh"

    # Check and add truststore configuration if not present
    if ! grep -q "javax.net.ssl.trustStore" "${setenv_file}" 2>/dev/null; then
        log_info "Adding truststore configuration to setenv.sh..."
        cat >> "${setenv_file}" << EOF

# PingDS Truststore Configuration
export CATALINA_OPTS="\$CATALINA_OPTS -Djavax.net.ssl.trustStore=${TRUSTSTORE_DEST}"
export CATALINA_OPTS="\$CATALINA_OPTS -Djavax.net.ssl.trustStorePassword=${TRUSTSTORE_PASSWORD}"
export CATALINA_OPTS="\$CATALINA_OPTS -Djavax.net.ssl.trustStoreType=PKCS12"
EOF
        log_success "Truststore configuration added to setenv.sh"
    else
        log_info "Truststore configuration already present in setenv.sh"
    fi

    # Check and add hostname verification disable if not present (CRITICAL for LDAPS)
    if ! grep -q "disableEndpointIdentification" "${setenv_file}" 2>/dev/null; then
        log_info "Adding hostname verification disable for LDAPS..."
        cat >> "${setenv_file}" << EOF

# Disable hostname verification for LDAPS connections in Docker network
# NOTE: This is acceptable for lab/dev environments with isolated networks.
# For production, use properly configured certificates with correct SANs.
export CATALINA_OPTS="\$CATALINA_OPTS -Dcom.sun.jndi.ldap.object.disableEndpointIdentification=true"
EOF
        log_success "Hostname verification disabled for Docker network (lab environment)"
    else
        log_info "Hostname verification disable already present in setenv.sh"
    fi

    chmod +x "${setenv_file}"
}

# Function to display AM startup info
display_startup_info() {
    log_info "=========================================="
    log_info "PingAM Container Starting"
    log_info "=========================================="
    log_info "Tomcat Home:     ${CATALINA_HOME}"
    log_info "Java Version:    $(java -version 2>&1 | head -n 1)"
    log_info "Truststore:      ${TRUSTSTORE_DEST}"
    log_info "HTTP Port:       8080"
    log_info "HTTPS Port:      8443"
    log_info "=========================================="
}

# Main execution
main() {
    display_startup_info

    # Wait for PingDS truststore (with timeout)
    if wait_for_truststore; then
        # Setup truststore for Tomcat
        setup_truststore

        # Configure Tomcat to use the truststore
        configure_tomcat_truststore

        log_info "=========================================="
        log_info "Truststore Setup Complete"
        log_info "=========================================="
        log_info "Certificate:     ${CERTS_DIR}/ds-ca-cert.pem"
        log_info "Truststore:      ${TRUSTSTORE_DEST}"
        log_info "Truststore Type: PKCS12"
        log_info "Password:        ${TRUSTSTORE_PASSWORD}"
        log_info "=========================================="
    else
        log_info "Proceeding without PingDS truststore"
        log_info "LDAPS connections to PingDS will likely fail"
    fi

    log_info "Starting Tomcat..."

    # Execute the command passed to the script (typically "catalina.sh run")
    exec "$@"
}

# Run main function with all script arguments
main "$@"
