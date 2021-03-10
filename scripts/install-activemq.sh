#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd $SCRIPT_PARENT_DIR

ACTIVEMQ_VER=5.16.1
JETTY_VER=9.4.35.v20201120

cd /tmp
curl -Lo apache-activemq-$ACTIVEMQ_VER-bin.tar.gz https://www.apache.org/dist/activemq/$ACTIVEMQ_VER/apache-activemq-$ACTIVEMQ_VER-bin.tar.gz
tar zxvf apache-activemq-$ACTIVEMQ_VER-bin.tar.gz
sudo mv /tmp/apache-activemq-$ACTIVEMQ_VER /opt/

# sudo useradd activemq

curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/jetty-jaas-$JETTY_VER.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-jaas/$JETTY_VER/jetty-jaas-$JETTY_VER.jar
curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/jetty-security-$JETTY_VER.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-security/$JETTY_VER/jetty-security-$JETTY_VER.jar
curl -Lo /opt/apache-activemq-$ACTIVEMQ_VER/lib/ldaptive-1.3.0.jar https://repo1.maven.org/maven2/org/ldaptive/ldaptive/1.3.0/ldaptive-1.3.0.jar

cd $SCRIPT_PARENT_DIR

cp ./conf/activemq.xml /opt/apache-activemq-5.16.1/conf/
cp ./conf/jetty.xml /opt/apache-activemq-5.16.1/conf/
cp ./conf/login.config /opt/apache-activemq-5.16.1/conf/
cp ./conf/log4j.properties /opt/apache-activemq-5.16.1/conf/

cd $LAUNCH_DIR