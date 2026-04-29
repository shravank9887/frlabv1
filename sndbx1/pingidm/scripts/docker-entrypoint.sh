#!/bin/sh
#
# PingIDM Docker entrypoint
# Based on ForgeRock's bundled entrypoint with overlay support
#

PROJECT_HOME="${PROJECT_HOME:-/opt/openidm}"
LOGGING_PROPERTIES="${LOGGING_PROPERTIES:-/opt/openidm/conf/logback.xml}"
JAVA_OPTS="${JAVA_OPTS:- -XX:MaxRAMPercentage=65 -XX:InitialRAMPercentage=65 -XX:MaxTenuringThreshold=1 -Djava.security.egd=file:/dev/urandom -XshowSettings:vm}"
OPENIDM_HOME=/opt/openidm

export IDM_ENVCONFIG_DIRS="${IDM_ENVCONFIG_DIRS:-/opt/openidm/resolver/}"

# Apply config overlay if present
if [ -d "${OPENIDM_HOME}/conf-overlay" ]; then
    echo "[ENTRYPOINT] Applying config overlay..."
    cp -f ${OPENIDM_HOME}/conf-overlay/*.json ${OPENIDM_HOME}/conf/ 2>/dev/null || true
    cp -f ${OPENIDM_HOME}/conf-overlay/*.properties ${OPENIDM_HOME}/conf/ 2>/dev/null || true
    # boot.properties lives in resolver/, not conf/
    if [ -f "${OPENIDM_HOME}/conf-overlay/boot.properties" ]; then
        cp -f ${OPENIDM_HOME}/conf-overlay/boot.properties ${OPENIDM_HOME}/resolver/boot.properties
        echo "[ENTRYPOINT] boot.properties overlay applied to resolver/"
    fi
    echo "[ENTRYPOINT] Config overlay applied."
fi

if [ "$1" = 'openidm' ]; then

    HOSTNAME=$(hostname)
    NODE_ID=${HOSTNAME}

    if [ -r secrets/keystore.jceks ]; then
        echo "[ENTRYPOINT] Copying keystores from secrets..."
        cp -L secrets/* security
    fi

    # Import DS-IDM CA certificate into IDM's truststore for startTLS
    CERTS_DIR="/opt/certs"
    DS_CA_CERT="${CERTS_DIR}/ds-idm-ca-cert.pem"
    IDM_TRUSTSTORE="${OPENIDM_HOME}/security/truststore"
    IDM_STOREPASS_FILE="${OPENIDM_HOME}/security/storepass"

    if [ -d "${CERTS_DIR}" ]; then
        # Wait for DS to export its certificate (max 90 seconds)
        echo "[ENTRYPOINT] Waiting for DS-IDM CA certificate..."
        WAIT=0
        while [ ! -f "${DS_CA_CERT}" ] && [ $WAIT -lt 90 ]; do
            sleep 3
            WAIT=$((WAIT + 3))
        done

        if [ -f "${DS_CA_CERT}" ]; then
            echo "[ENTRYPOINT] DS-IDM CA certificate found. Importing into IDM truststore..."

            # Read the storepass
            STOREPASS="changeit"
            if [ -f "${IDM_STOREPASS_FILE}" ]; then
                STOREPASS=$(cat "${IDM_STOREPASS_FILE}")
            fi

            # Check if alias already exists, delete if so (for cert rotation)
            keytool -list -alias ds-idm-ca \
                -keystore "${IDM_TRUSTSTORE}" \
                -storepass "${STOREPASS}" > /dev/null 2>&1 && \
            keytool -delete -alias ds-idm-ca \
                -keystore "${IDM_TRUSTSTORE}" \
                -storepass "${STOREPASS}" > /dev/null 2>&1

            # Import DS CA certificate
            if keytool -import \
                -noprompt \
                -trustcacerts \
                -alias ds-idm-ca \
                -file "${DS_CA_CERT}" \
                -keystore "${IDM_TRUSTSTORE}" \
                -storepass "${STOREPASS}" 2>/dev/null; then
                echo "[ENTRYPOINT] DS-IDM CA certificate imported successfully into ${IDM_TRUSTSTORE}"
            else
                echo "[ENTRYPOINT] WARNING: Failed to import DS-IDM CA cert. DS connection may fail with TLS."
            fi

            echo "[ENTRYPOINT] DS-IDM CA certificate import done."
        else
            echo "[ENTRYPOINT] WARNING: DS-IDM CA certificate not found after 90s. Continuing without TLS cert import."
            echo "[ENTRYPOINT] IDM may fail to connect to DS if startTLS is configured."
        fi
    fi

    # Import DS (AM) CA certificate for LDAP connector to pingds
    CERTS_AM_DIR="/opt/certs-am"
    DS_AM_CA_CERT="${CERTS_AM_DIR}/ds-ca-cert.pem"

    if [ -f "${DS_AM_CA_CERT}" ]; then
        echo "[ENTRYPOINT] DS (AM) CA certificate found. Importing into IDM truststore..."

        STOREPASS="changeit"
        if [ -f "${IDM_STOREPASS_FILE}" ]; then
            STOREPASS=$(cat "${IDM_STOREPASS_FILE}")
        fi

        # Delete existing alias if present (for rotation)
        keytool -list -alias ds-am-ca \
            -keystore "${IDM_TRUSTSTORE}" \
            -storepass "${STOREPASS}" > /dev/null 2>&1 && \
        keytool -delete -alias ds-am-ca \
            -keystore "${IDM_TRUSTSTORE}" \
            -storepass "${STOREPASS}" > /dev/null 2>&1

        if keytool -import \
            -noprompt \
            -trustcacerts \
            -alias ds-am-ca \
            -file "${DS_AM_CA_CERT}" \
            -keystore "${IDM_TRUSTSTORE}" \
            -storepass "${STOREPASS}" 2>/dev/null; then
            echo "[ENTRYPOINT] DS (AM) CA certificate imported successfully (alias: ds-am-ca)"
        else
            echo "[ENTRYPOINT] WARNING: Failed to import DS (AM) CA cert. LDAP connector to pingds may fail."
        fi
    else
        echo "[ENTRYPOINT] DS (AM) CA certificate not found at ${DS_AM_CA_CERT}. LDAP connector will not have TLS trust for pingds."
    fi

    # Show final truststore state
    echo "[ENTRYPOINT] Truststore contents:"
    keytool -list -keystore "${IDM_TRUSTSTORE}" -storepass "${STOREPASS}" 2>/dev/null | grep -i "ds-" || true

    BUNDLE_PATH="$OPENIDM_HOME/bundle"

    find_bundle_file () {
        echo "$(find "${BUNDLE_PATH}" -name $1)"
    }

    SLF4J_API=$(find_bundle_file "slf4j-api-[0-9]*.jar")
    JUL_TO_SLF4J=$(find_bundle_file "jul-to-slf4j-[0-9]*.jar")
    SLF4J_LOGBACK_CLASSIC=$(find_bundle_file "logback-classic-*.jar")
    SLF4J_LOGBACK_CORE=$(find_bundle_file "logback-core-*.jar")
    JACKSON_CORE=$(find_bundle_file "jackson-core-[0-9]*.jar")
    JACKSON_DATABIND=$(find_bundle_file "jackson-databind-[0-9]*.jar")
    JACKSON_ANNOTATIONS=$(find_bundle_file "jackson-annotations-[0-9]*.jar")
    BC_FIPS=$(find_bundle_file "bc-fips-[0-9]*.jar")
    BC_PKIX=$(find_bundle_file "bcpkix-fips-[0-9]*.jar")
    BC_TLS=$(find_bundle_file "bctls-fips-[0-9]*.jar")
    BC_MAIL=$(find_bundle_file "bcmail-fips-[0-9]*.jar")
    BC_UTIL=$(find_bundle_file "bcutil-fips-[0-9]*.jar")

    SLF4J_PATHS="$SLF4J_API:$SLF4J_LOGBACK_CLASSIC:$SLF4J_LOGBACK_CORE:$JUL_TO_SLF4J"
    JACKSON_PATHS="$JACKSON_CORE:$JACKSON_DATABIND:$JACKSON_ANNOTATIONS"
    BC_PATHS="$BC_FIPS:$BC_PKIX:$BC_TLS:$BC_MAIL:$BC_UTIL"
    OPENIDM_SYSTEM_PATH=$(echo $BUNDLE_PATH/openidm-system-*.jar)
    OPENIDM_UTIL_PATH=$(echo $BUNDLE_PATH/openidm-util-*.jar)

    CLASSPATH="$OPENIDM_HOME/bin/*:$OPENIDM_HOME/framework/*:$SLF4J_PATHS:$JACKSON_PATHS:$BC_PATHS:$OPENIDM_SYSTEM_PATH:$OPENIDM_UTIL_PATH:${IDM_CLASSPATH:-}"

    echo "[ENTRYPOINT] Starting PingIDM on port ${OPENIDM_HTTP_PORT:-8082}..."

    exec java ${JAVA_OPTS} \
        --add-opens java.base/java.lang=ALL-UNNAMED \
        --add-opens java.base/java.util=ALL-UNNAMED \
        -Dlogback.configurationFile="${LOGGING_PROPERTIES}" \
        -Djava.endorsed.dirs="${JAVA_ENDORSED_DIRS:-}" \
        -classpath "${CLASSPATH}" \
        -Dopenidm.system.server.root=/opt/openidm \
        -Djava.awt.headless=true \
        -Dopenidm.node.id="${NODE_ID}" \
        -Djava.security.properties="${PROJECT_HOME}/conf/java.security" \
        -XX:+ExitOnOutOfMemoryError \
        org.forgerock.openidm.launcher.Main -c /opt/openidm/bin/launcher.json \
        -p "${PROJECT_HOME}"
fi

exec "$@"
