# Build stage
#-------------------------------------#
FROM maven:3.5.2-jdk-8-alpine as build

# Copy connectors
COPY . .
RUN mvn clean package -DskipTests
#-------------------------------------#

# Runtime stage
#-------------------------------------#
FROM frekele/java:jdk8
MAINTAINER jkabonick@frontlineed.com

# Install kafka
ENV SCALA_VERSION="2.11" \
    KAFKA_VERSION="0.11.0.2"
ENV KAFKA_HOME=/opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}

ARG KAFKA_DIST=kafka_${SCALA_VERSION}-${KAFKA_VERSION}
ARG KAFKA_DIST_TGZ=${KAFKA_DIST}.tgz
ARG KAFKA_DIST_ASC=${KAFKA_DIST}.tgz.asc

RUN set -x && \
    apt update && \
    apt update && \
    apt install libonig4 && \
    apt install libjq1 && \
    apt install jq && \
    apt install unzip curl ca-certificates gnupg && \
    eval $(gpg-agent --daemon) && \
    MIRROR=`curl -sSL https://www.apache.org/dyn/closer.cgi\?as_json\=1 | jq -r '.preferred'` && \
    curl -sSLO "${MIRROR}kafka/${KAFKA_VERSION}/${KAFKA_DIST_TGZ}" && \
    curl -sSLO https://dist.apache.org/repos/dist/release/kafka/${KAFKA_VERSION}/${KAFKA_DIST_ASC} && \
    curl -sSL  https://kafka.apache.org/KEYS | gpg -q --import - && \
    gpg -q --verify ${KAFKA_DIST_ASC} && \
    mkdir -p /opt && \
    mv ${KAFKA_DIST_TGZ} /tmp && \
    tar xfz /tmp/${KAFKA_DIST_TGZ} -C /opt && \
    rm /tmp/${KAFKA_DIST_TGZ} &&\
    apt --yes remove unzip curl ca-certificates gnupg jq libjq1 libonig4

# Set env
ENV PATH=$PATH:/${KAFKA_HOME}/bin \
    CONNECT_CFG=${KAFKA_HOME}/config/connect-distributed.properties \
    CONNECT_BIN=${KAFKA_HOME}/bin/connect-distributed.sh

ENV JMX_PORT=9999 \
    CONNECT_PORT=8083

EXPOSE ${JMX_PORT}
EXPOSE ${CONNECT_PORT}

# Copy connectors
COPY --from=build target/connect-mongodb-1.1-jar-with-dependencies.jar $KAFKA_HOME/connectors/connect-mongodb-1.1-jar-with-dependencies.jar

WORKDIR $KAFKA_HOME

COPY start-connect.sh $KAFKA_HOME/start-connect.sh
RUN chmod +x $KAFKA_HOME/start-connect.sh

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["./start-connect.sh"]