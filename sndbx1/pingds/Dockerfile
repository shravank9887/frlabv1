FROM eclipse-temurin:21-jre-jammy

# Metadata
LABEL maintainer="forgerock-sandbox"
LABEL description="PingDS 8 for ForgeRock Sandbox Environment"
LABEL version="8.0"


# Set environment variables
ENV PINGDS_HOME=/opt/opendj \
    PINGDS_INSTANCE=/opt/opendj \
    JAVA_HOME=/opt/java/openjdk \
    PATH="${PATH}:/opt/opendj/bin" \
    DEBIAN_FRONTEND=noninteractive \
    # DS-specific JVM tuning
    OPENDJ_JAVA_ARGS="-server -Xmx1g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        unzip \
        openssl \
        ca-certificates \
        dnsutils \
        iputils-ping \
        netcat-openbsd \
        vim \
        less \
        procps \
        # For LDAP troubleshooting
        ldap-utils \
        # For privilege dropping in entrypoint
        gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories with proper structure
RUN mkdir -p ${PINGDS_HOME} \
             /opt/pingds-data \
             /opt/certs \
             /opt/scripts \
             /opt/backups \
             /opt/logs

# Set working directory
WORKDIR /opt

# Copy PingDS zip file
COPY software/DS-*.zip /tmp/

# Extract and setup PingDS
RUN cd /tmp && \
    unzip -q DS-*.zip -d /tmp/pingds && \
    # Check if extraction was successful
    if [ ! -d "/tmp/pingds/opendj" ]; then \
        echo "ERROR: PingDS extraction failed - opendj directory not found"; \
        exit 1; \
    fi && \
    mv /tmp/pingds/opendj/* ${PINGDS_HOME}/ && \
    # Verify critical files exist
    if [ ! -f "${PINGDS_HOME}/setup" ]; then \
        echo "ERROR: PingDS setup file not found"; \
        exit 1; \
    fi && \
    chmod -R +x ${PINGDS_HOME}/bin && \
    chmod +x ${PINGDS_HOME}/setup && \
    # Clean up
    rm -rf /tmp/DS-*.zip /tmp/pingds

# Copy scripts
COPY scripts/*.sh /opt/scripts/
RUN chmod +x /opt/scripts/*.sh

# Create pingds user and group with specific UID/GID for consistency
# Using UID/GID 1000 makes it compatible with most systems
RUN groupadd -r pingds -g 1000 && \
    useradd -r -u 1000 -g pingds -d ${PINGDS_HOME} -s /bin/bash -c "PingDS Service Account" pingds

# Set ownership AFTER all files are in place
RUN chown -R pingds:pingds ${PINGDS_HOME} \
                            /opt/pingds-data \
                            /opt/certs \
                            /opt/backups \
                            /opt/scripts \
                            /opt/logs

# Expose ports
# 1389  - LDAP
# 1636  - LDAPS  
# 4444  - Admin connector
# 8080  - HTTP (REST API)
# 8443  - HTTPS (REST API)
EXPOSE 1389 1636 4444 8080 8443

# Health check - simplified to avoid authentication issues during startup
# This checks if LDAP port is accepting connections
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD nc -z localhost 1389 || exit 1

# Volumes for persistence
VOLUME ["/opt/pingds-data", "/opt/certs", "/opt/backups", "/opt/logs"]

# Keep as root user initially to fix volume permissions
# The entrypoint script will handle permission fixes and then run as pingds
USER root

# Entrypoint wrapper that fixes permissions then drops to pingds user
ENTRYPOINT ["/opt/scripts/docker-entrypoint.sh"]

# Default command
CMD ["start-server"]