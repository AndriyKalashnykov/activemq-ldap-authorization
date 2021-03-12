FROM openjdk:8-jre

ENV ACTIVEMQ_VER 5.16.1
ENV JETTY_VER=9.4.35.v20201120
ENV LDAPTIVE_VER=1.2.4
ENV ACTIVEMQ apache-activemq-$ACTIVEMQ_VER
ENV ACTIVEMQ_TCP=61616 ACTIVEMQ_AMQP=5672 ACTIVEMQ_STOMP=61613 ACTIVEMQ_MQTT=1883 ACTIVEMQ_WS=61614 ACTIVEMQ_UI=8161
ENV SHA512_VAL=f98c9da5dafa2dc291070fecd57b7fccd0954cc8b2be09abc77ea66745b89283358297f308ec30dd47efd3e0c9d4cffc3821ef429f8f94d6c8971bbe933809b2

# RUN apt-get update && yes | apt-get upgrade 
# RUN yes | apt-get install lsof net-tools nmap

ENV ACTIVEMQ_HOME /opt/activemq

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

RUN curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/jetty-jaas-$JETTY_VER.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-jaas/$JETTY_VER/jetty-jaas-$JETTY_VER.jar
RUN curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/jetty-security-$JETTY_VER.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-security/$JETTY_VER/jetty-security-$JETTY_VER.jar
RUN curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/ldaptive-$LDAPTIVE_VER.jar https://repo1.maven.org/maven2/org/ldaptive/ldaptive/$LDAPTIVE_VER/ldaptive-$LDAPTIVE_VER.jar

ADD init.sh /app/init.sh

WORKDIR $ACTIVEMQ_HOME
EXPOSE $ACTIVEMQ_TCP $ACTIVEMQ_AMQP $ACTIVEMQ_STOMP $ACTIVEMQ_MQTT $ACTIVEMQ_WS $ACTIVEMQ_UI

ENTRYPOINT ["/app/init.sh"]
CMD ["/bin/sh", "-c", "/app/init.sh"]s
# CMD ["/bin/sh", "-c", "bin/activemq console"]