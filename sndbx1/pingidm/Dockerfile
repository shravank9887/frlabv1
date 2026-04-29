FROM eclipse-temurin:21-jre-jammy

LABEL maintainer="forgerock-sandbox"
LABEL description="PingIDM 8.0.1 for ForgeRock Sandbox Environment"
LABEL version="8.0.1"

# Install fonts required by Flowable workflow engine
RUN apt-get update && \
    apt-get install -y --no-install-recommends fonts-dejavu curl unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create IDM user
RUN groupadd -r openidm -g 11111 && \
    useradd -r -u 11111 -g openidm -d /opt/openidm -s /bin/bash -c "PingIDM Service" openidm

# Copy and extract IDM
COPY software/IDM-8.0.1.zip /tmp/
RUN cd /tmp && \
    unzip -q IDM-8.0.1.zip -d /tmp/idm && \
    mv /tmp/idm/openidm /opt/openidm && \
    rm -rf /tmp/IDM-8.0.1.zip /tmp/idm

# Copy custom configs (overlaid on top of defaults)
COPY conf/ /opt/openidm/conf-overlay/
COPY scripts/docker-entrypoint.sh /opt/openidm/bin/docker-entrypoint.sh

# Create certs mount point
RUN mkdir -p /opt/certs

RUN sed -i 's/\r$//' /opt/openidm/bin/docker-entrypoint.sh && \
    chmod +x /opt/openidm/bin/docker-entrypoint.sh && \
    chmod +x /opt/openidm/startup.sh && \
    chown -R openidm:openidm /opt/openidm /opt/certs

WORKDIR /opt/openidm

EXPOSE 8082 8443

VOLUME ["/opt/openidm/logs", "/opt/openidm/audit"]

USER 11111

ENTRYPOINT ["/opt/openidm/bin/docker-entrypoint.sh", "openidm"]
