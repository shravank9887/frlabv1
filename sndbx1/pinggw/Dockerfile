# PingGateway (Identity Gateway) Dockerfile
FROM eclipse-temurin:21-jre-jammy

# Metadata
LABEL maintainer="forgerock-sandbox"
LABEL description="PingGateway 2025.11.1 (Identity Gateway)"
LABEL version="2025.11.1"

# Environment variables
ENV INSTALL_DIR=/opt/ig \
    IG_INSTANCE_DIR=/var/ig \
    DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        ca-certificates \
        netcat-openbsd \
        vim \
        less && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p ${INSTALL_DIR} \
             ${IG_INSTANCE_DIR}/config/routes \
             ${IG_INSTANCE_DIR}/extra

# Copy and extract PingGateway
COPY software/PingGateway-2025.11.1.zip /tmp/
RUN cd /tmp && \
    unzip -q PingGateway-2025.11.1.zip && \
    cp -a identity-gateway-2025.11.1/* ${INSTALL_DIR}/ && \
    chmod +x ${INSTALL_DIR}/bin/*.sh && \
    rm -rf /tmp/PingGateway-2025.11.1.zip /tmp/identity-gateway-2025.11.1

# Create iguser with UID 1002
RUN groupadd -r iguser -g 1002 && \
    useradd -r -u 1002 -g iguser -d ${IG_INSTANCE_DIR} -s /bin/bash -c "PingGateway Service Account" iguser

# Set ownership
RUN chown -R iguser:iguser ${INSTALL_DIR} ${IG_INSTANCE_DIR}

# Switch to non-root user
USER iguser

# Expose ports: 8080 (app), 9000 (admin)
EXPOSE 8080 9000

# JVM tuning
ENV IG_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC"

# Start PingGateway with instance directory
ENTRYPOINT ["/opt/ig/bin/start.sh", "/var/ig"]
