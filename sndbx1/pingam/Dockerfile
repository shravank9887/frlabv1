# PingAM (Access Manager) Dockerfile
FROM tomcat:10-jdk21

# Metadata
LABEL maintainer="forgerock-sandbox"
LABEL description="PingAM 8.0.2 on Apache Tomcat 10 with JDK 21"
LABEL version="8.0.2"

# Environment variables
ENV CATALINA_HOME=/usr/local/tomcat \
    CATALINA_BASE=/usr/local/tomcat \
    AM_HOME=/opt/am \
    AM_CONFIG_DIR=/opt/am-config \
    CERTS_DIR=/opt/certs

# Install additional utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        openssl \
        ca-certificates \
        netcat-openbsd \
        vim \
        less \
        dos2unix && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p ${AM_HOME} \
             ${AM_CONFIG_DIR} \
             ${CATALINA_HOME}/conf/keystores \
             ${CERTS_DIR} \
             /opt/scripts && \
    chmod 755 ${AM_HOME} ${AM_CONFIG_DIR} ${CATALINA_HOME}/conf/keystores /opt/scripts

# Configure JVM settings by appending to setenv.sh
# Sets minimum heap to 1GB, maximum to 2GB, with Metaspace and GC tuning
RUN echo '' >> ${CATALINA_BASE}/bin/setenv.sh && \
    echo '# PingAM JVM Configuration' >> ${CATALINA_BASE}/bin/setenv.sh && \
    echo 'export CATALINA_OPTS="$CATALINA_OPTS -server -Xms1g -Xmx2g -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=256m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"' >> ${CATALINA_BASE}/bin/setenv.sh && \
    chmod +x ${CATALINA_BASE}/bin/setenv.sh

# Remove default Tomcat webapps to save space and reduce attack surface
RUN rm -rf ${CATALINA_HOME}/webapps/*

# Copy AM WAR file
# Note: Place AM-8.0.2.war in pingam/software/ before building
COPY software/AM-*.war ${CATALINA_HOME}/webapps/am.war

# Verify WAR file was copied
RUN if [ ! -f "${CATALINA_HOME}/webapps/am.war" ]; then \
        echo "ERROR: AM WAR file not found"; \
        exit 1; \
    fi

# Set proper ownership and permissions
RUN chown -R root:root ${CATALINA_HOME}/webapps && \
    chmod 644 ${CATALINA_HOME}/webapps/am.war

# Copy entrypoint script and fix line endings
COPY scripts/docker-entrypoint.sh /opt/scripts/docker-entrypoint.sh
RUN dos2unix /opt/scripts/docker-entrypoint.sh && \
    chmod +x /opt/scripts/docker-entrypoint.sh

# Create tomcat user and group with specific UID/GID for consistency
# Using UID/GID 1001 (1000 is used by pingds)
RUN groupadd -r tomcat -g 1001 && \
    useradd -r -u 1001 -g tomcat -d ${CATALINA_HOME} -s /bin/bash -c "Tomcat Service Account" tomcat

# Set ownership to tomcat user AFTER all files are in place
RUN chown -R tomcat:tomcat ${CATALINA_HOME} \
                            ${AM_HOME} \
                            ${AM_CONFIG_DIR} \
                            ${CERTS_DIR} \
                            /opt/scripts

# Switch to tomcat user (non-root for security)
USER tomcat

# Expose ports
# 8080 - HTTP
# 8443 - HTTPS
EXPOSE 8080 8443

# Health check - verify AM is deployed and responding
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=120s \
    CMD curl -f http://localhost:8080/am/isAlive.jsp || exit 1

# Entrypoint script handles truststore setup and starts Tomcat
ENTRYPOINT ["/opt/scripts/docker-entrypoint.sh"]

# Default command - starts Tomcat in foreground
CMD ["catalina.sh", "run"]
