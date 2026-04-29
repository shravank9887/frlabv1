FROM eclipse-temurin:21-jre-jammy

LABEL maintainer="forgerock-sandbox"
LABEL description="PingDS 8 - IDM Repository Backend"
LABEL version="8.0"

ENV PINGDS_HOME=/opt/opendj \
    JAVA_HOME=/opt/java/openjdk \
    PATH="${PATH}:/opt/opendj/bin" \
    DEBIAN_FRONTEND=noninteractive \
    OPENDJ_JAVA_ARGS="-server -Xmx512m -XX:+UseG1GC"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl unzip openssl ca-certificates netcat-openbsd gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${PINGDS_HOME} /opt/pingds-data /opt/certs /opt/scripts

WORKDIR /opt

# Reuse the same DS software as pingds
COPY software/DS-*.zip /tmp/

RUN cd /tmp && \
    unzip -q DS-*.zip -d /tmp/pingds && \
    mv /tmp/pingds/opendj/* ${PINGDS_HOME}/ && \
    chmod -R +x ${PINGDS_HOME}/bin && \
    chmod +x ${PINGDS_HOME}/setup && \
    rm -rf /tmp/DS-*.zip /tmp/pingds

COPY scripts/*.sh /opt/scripts/
RUN sed -i 's/\r$//' /opt/scripts/*.sh && chmod +x /opt/scripts/*.sh

RUN groupadd -r pingds -g 1001 && \
    useradd -r -u 1001 -g pingds -d ${PINGDS_HOME} -s /bin/bash -c "PingDS IDM Repo" pingds

RUN chown -R pingds:pingds ${PINGDS_HOME} /opt/pingds-data /opt/certs /opt/scripts

EXPOSE 2389 2636 5444

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD nc -z localhost 2389 || exit 1

VOLUME ["/opt/pingds-data", "/opt/certs"]

USER root

ENTRYPOINT ["/opt/scripts/docker-entrypoint.sh"]
CMD ["start-server"]
