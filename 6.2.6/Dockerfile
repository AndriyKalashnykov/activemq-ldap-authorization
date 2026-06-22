FROM eclipse-temurin:25.0.3_9-jre

LABEL maintainer="AndriyKalashnykov@gmail.com"

# bash + pipefail: makes the `sha512sum | awk` pipe fail correctly (DL4006)
# and brace expansion in the apt cleanup well-defined (SC3009).
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV ACTIVEMQ_VER=6.2.6
ENV JETTY_VER=11.0.26
ENV ACTIVEMQ=apache-activemq-$ACTIVEMQ_VER
ENV ACTIVEMQ_TCP=61616 ACTIVEMQ_AMQP=5672 ACTIVEMQ_STOMP=61613 ACTIVEMQ_MQTT=1883 ACTIVEMQ_WS=61614 ACTIVEMQ_UI=8161
ENV SHA512_VAL=2b1e0c0e7336d86475c6a2149326ef9055542f04d34c3c6f4c18a0d79e2ef41dd033bbecfef2abe9117dd34b767c5c9714e349305ffc0117e210852359277172

# curl is installed explicitly: the eclipse-temurin:25 base (Ubuntu 24.04)
# dropped curl from the image, unlike the older :11-jre (Jammy) base that
# shipped it. The ActiveMQ tarball below is fetched with curl.
# `rm /usr/bin/pebble`: the temurin:25 base ships a stray ~10 MB Go ACME-test
# binary (not apt-managed, not dpkg-owned) the broker never uses; it carried 8
# HIGH Go-stdlib CVEs. Removing it is attack-surface reduction, not a workaround.
RUN apt-get update && apt-get upgrade --yes && apt-get install --yes --no-install-recommends curl openssl lsof net-tools nmap && apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/ && rm -f /usr/bin/pebble

ENV ACTIVEMQ_HOME=/opt/activemq

RUN curl -Lo $ACTIVEMQ-bin.tar.gz "https://archive.apache.org/dist/activemq/$ACTIVEMQ_VER/$ACTIVEMQ-bin.tar.gz" 

# Validate checksum
RUN if [ "$SHA512_VAL" != "$(sha512sum $ACTIVEMQ-bin.tar.gz | awk '{print($1)}')" ];\
    then \
        echo "sha512 values doesn't match! exiting."  && \
        exit 1; \
    fi;

# lib/camel/ (camel-core 2.25.4 + camel-jms/-spring) is removed: the templated
# activemq.xml declares no <camelContext>/import, so the camel route engine is
# never loaded. camel 2.x is EOL (CVE-2020-11971 has no 2.x fix); deleting the
# dormant jars eliminates the finding outright rather than suppressing it.
#
# lib/optional/{shiro-core,shiro-spring}-2.2.0.jar + activemq-shiro-6.2.6.jar are
# removed for the same reason: Shiro is ActiveMQ's OPTIONAL security module,
# active only when activemq.xml declares a <shiro>/shiroSecurityManager bean.
# This demo authenticates via JAAS (jaasAuthenticationPlugin + LDAPLoginModule),
# never Shiro, so the module is never loaded. shiro-core 2.2.0 carries
# CVE-2026-49268 (HIGH, LDAP DN injection); deleting the dormant module
# eliminates the finding outright rather than waiving it. Verified by the full
# e2e auth/authz contract passing with these jars absent.
RUN tar xzf $ACTIVEMQ-bin.tar.gz -C  /opt && \
    ln -s /opt/$ACTIVEMQ $ACTIVEMQ_HOME && \
    useradd -r -M -d $ACTIVEMQ_HOME activemq && \
    chown -R activemq:activemq /opt/$ACTIVEMQ && \
    chown -h activemq:activemq $ACTIVEMQ_HOME && \
    rm -rf /opt/$ACTIVEMQ/lib/camel && \
    rm -f /opt/$ACTIVEMQ/lib/optional/shiro-core-*.jar \
          /opt/$ACTIVEMQ/lib/optional/shiro-spring-*.jar \
          /opt/$ACTIVEMQ/lib/optional/activemq-shiro-*.jar

USER activemq

COPY ./conf/* $ACTIVEMQ_HOME/conf/
COPY ./bin/* $ACTIVEMQ_HOME/bin/

COPY init.sh /app/init.sh

WORKDIR $ACTIVEMQ_HOME
EXPOSE $ACTIVEMQ_TCP $ACTIVEMQ_AMQP $ACTIVEMQ_STOMP $ACTIVEMQ_MQTT $ACTIVEMQ_WS $ACTIVEMQ_UI

ENTRYPOINT ["/app/init.sh"]