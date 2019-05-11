FROM debian:stretch
LABEL maintainer="longqinsi@hotmail.com"

# set user configurations
ARG USER=cassandra
ARG USER_ID=802
ARG USER_GROUP=cassandra
ARG USER_GROUP_ID=802
ARG USER_HOME=/home/${USER}
# set dependant files directory
ARG FILES=./files
# set jdk configurations
ARG JDK=jdk8u*
ARG JAVA_HOME=${USER_HOME}/java
# set cassandra product configurations
ARG CASSANDRA_SERVER=apache-cassandra
ARG CASSANDRA_SERVER_VERSION=3.11.4
ARG CASSANDRA_SERVER_PACK=${CASSANDRA_SERVER}-${CASSANDRA_SERVER_VERSION}
ARG CASSANDRA_SERVER_HOME=${USER_HOME}/${CASSANDRA_SERVER_PACK}

# create a user group and a user
RUN groupadd --system -g ${USER_GROUP_ID} ${USER_GROUP} && \
    useradd --system --create-home --home-dir ${USER_HOME} --no-log-init -g ${USER_GROUP_ID} -u ${USER_ID} ${USER}

COPY ${FILES}/etc/apt/sources.list /etc/apt/

RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
# solves warning: "jemalloc shared library could not be preloaded to speed up memory allocations"
		libjemalloc1 \
# free is used by cassandra-env.sh
		procps \
# "ip" is not required by Cassandra itself, but is commonly used in scripting Cassandra's configuration (since it is so fixated on explicit IP addresses)
		iproute2 \
	; \
	if ! command -v gpg > /dev/null; then \
		apt-get install -y --no-install-recommends \
			dirmngr \
			gnupg \
		; \
	fi; \
	rm -rf /var/lib/apt/lists/*

# copy the jdk and cassandra product distributions to user's home directory
COPY --chown=cassandra:cassandra ${FILES}/${JDK} ${USER_HOME}/java/
COPY --chown=cassandra:cassandra ${FILES}/${CASSANDRA_SERVER_PACK}/ ${CASSANDRA_SERVER_HOME}/
# copy jvm.options file to cassandra's conf directory which resets jvm memory to 1G
COPY --chown=cassandra:cassandra ${FILES}/jvm.options ${CASSANDRA_SERVER_HOME}/conf/

# set the user and work directory
USER ${USER_ID}
WORKDIR ${USER_HOME}

# set environment variables
ENV JAVA_HOME=${JAVA_HOME} \
    CASSANDRA_SERVER_HOME=${CASSANDRA_SERVER_HOME} \
    PATH=$CASSANDRA_SERVER_HOME/bin:$JAVA_HOME/bin:$PATH \
    WORKING_DIRECTORY=${USER_HOME} \
    CASSANDRA_CONFIG=${CASSANDRA_SERVER_HOME}/conf

COPY --chown=cassandra:cassandra ${FILES}/docker-entrypoint.sh ${CASSANDRA_SERVER_HOME}/bin
RUN chmod +x ${CASSANDRA_SERVER_HOME}/bin/docker-entrypoint.sh \
        && mkdir ${CASSANDRA_SERVER_HOME}/data \
        && chown -R cassandra:cassandra ${CASSANDRA_SERVER_HOME}/data \
        && chmod 777 ${CASSANDRA_SERVER_HOME}/conf ${CASSANDRA_SERVER_HOME}/data
ENTRYPOINT ["docker-entrypoint.sh"]

VOLUME ${CASSANDRA_SERVER_HOME}/data

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160
CMD ["cassandra", "-f"]