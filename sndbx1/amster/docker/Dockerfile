#
# Copyright 2019-2025 Ping Identity Corporation. All Rights Reserved
#
FROM gcr.io/forgerock-io/java-17:latest

ENV FORGEROCK_HOME /home/forgerock

# Install a number of utilities. Not all containers will need all of these - but these are quite small in size.
# dnsutils for dig (dns diagnostics)
# iputils-ping - ping command
RUN apt-get update && apt-get upgrade -y && apt-get install -y unzip curl dnsutils iputils-ping sysstat

COPY build/ /build

RUN unzip -q /build/amster.zip && \
    mv amster/ /opt/amster && \
    rm -rf /build /opt/amster/docker && \
    chown -R forgerock:root /opt

COPY *.sh /opt/amster/
COPY *.sh /usr/local/bin/

# git is added to the container so we can optionally execute git commit, git push, etc.
RUN chmod 775 /opt/amster/amster \
    && chown -R forgerock /opt

WORKDIR /opt/amster

USER 11111

ENTRYPOINT ["/opt/amster/docker-entrypoint.sh"]

CMD ["configure"]
