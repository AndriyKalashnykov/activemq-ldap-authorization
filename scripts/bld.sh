#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd ~/projects/jetty.project/jetty-jaas

mvn clean package -DskipTests -Dmaven.test.skip=true

cp ~/projects/jetty.project/jetty-jaas/target/jetty-jaas-9.4.35.v20201120.jar /opt/apache-activemq-5.16.1/lib
# cp ~/projects/jetty.project/jetty-security/target/jetty-security-9.4.35.v20201120.jar /opt/apache-activemq-5.16.1/lib

cd $LAUNCH_DIR
