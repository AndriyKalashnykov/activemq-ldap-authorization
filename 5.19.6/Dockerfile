FROM eclipse-temurin:25.0.3_9-jre

LABEL maintainer="AndriyKalashnykov@gmail.com"

# bash + pipefail: makes the `sha512sum | awk` pipe fail correctly (DL4006)
# and brace expansion in the apt cleanup well-defined (SC3009).
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV ACTIVEMQ_VER=5.19.6
ENV JETTY_VER=9.4.58.v20250814
ENV ACTIVEMQ=apache-activemq-$ACTIVEMQ_VER
ENV ACTIVEMQ_TCP=61616 ACTIVEMQ_AMQP=5672 ACTIVEMQ_STOMP=61613 ACTIVEMQ_MQTT=1883 ACTIVEMQ_WS=61614 ACTIVEMQ_UI=8161
ENV SHA512_VAL=cdf98fd42501bda694dbcee85bfaf33d8548091402f9cb2e768bc2e0b0905972022caea10deacb6db2e04d2d461b683269186c07bd5327333bc0d50956b66b48

# curl is installed explicitly: the eclipse-temurin:25 base (Ubuntu 24.04)
# dropped curl from the image, unlike the older :11-jre (Jammy) base that
# shipped it. The ActiveMQ tarball + Jetty jars below are fetched with curl.
RUN apt-get update && apt-get upgrade --yes && apt-get install --yes --no-install-recommends curl openssl lsof net-tools nmap && apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/

ENV ACTIVEMQ_HOME=/opt/activemq

RUN curl -Lo $ACTIVEMQ-bin.tar.gz "https://archive.apache.org/dist/activemq/$ACTIVEMQ_VER/$ACTIVEMQ-bin.tar.gz" 

# Validate checksum
RUN if [ "$SHA512_VAL" != "$(sha512sum $ACTIVEMQ-bin.tar.gz | awk '{print($1)}')" ];\
    then \
        echo "sha512 values doesn't match! exiting."  && \
        exit 1; \
    fi;

RUN tar xzf $ACTIVEMQ-bin.tar.gz -C  /opt && \
    ln -s /opt/$ACTIVEMQ $ACTIVEMQ_HOME && \
    useradd -r -M -d $ACTIVEMQ_HOME activemq && \
    chown -R activemq:activemq /opt/$ACTIVEMQ && \
    chown -h activemq:activemq $ACTIVEMQ_HOME 

USER activemq

COPY ./conf/* $ACTIVEMQ_HOME/conf/
COPY ./bin/* $ACTIVEMQ_HOME/bin/

RUN curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/jetty-util-$JETTY_VER.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/$JETTY_VER/jetty-util-$JETTY_VER.jar && \
    curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/jetty-jaas-$JETTY_VER.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-jaas/$JETTY_VER/jetty-jaas-$JETTY_VER.jar && \
    curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/jetty-security-$JETTY_VER.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-security/$JETTY_VER/jetty-security-$JETTY_VER.jar


COPY init.sh /app/init.sh

WORKDIR $ACTIVEMQ_HOME
EXPOSE $ACTIVEMQ_TCP $ACTIVEMQ_AMQP $ACTIVEMQ_STOMP $ACTIVEMQ_MQTT $ACTIVEMQ_WS $ACTIVEMQ_UI

ENTRYPOINT ["/app/init.sh"]