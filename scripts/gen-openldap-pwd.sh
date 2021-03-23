#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);
. $SCRIPT_DIR/set-env.sh

PWD=${1:-admin}
ALG=${2:-SHA}

PWD_HASH=$(docker exec $OPENLDAP_CONTAINER slappasswd -h {$ALG} -s $PWD)
echo "PWD: $PWD, PWD_HASH: $PWD_HASH, ALG: $ALG,"

# https://stackoverflow.com/questions/57105919/encrypting-the-web-console-password-in-activemq
# curl -Lo lib/jetty-util-9.4.35.v20201120.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/9.4.35.v20201120/jetty-util-9.4.35.v20201120.jar
# java -cp lib/jetty-util-$JETTY_VER.jar org.eclipse.jetty.util.security.Password admin
# admin
# OBF:1u2a1toa1w8v1tok1u30
# MD5:21232f297a57a5a743894a0e4a801fc3
# activemq.xml 
# connectionPassword="MD5:21232f297a57a5a743894a0e4a801fc3"
# jetty-realm.properties
# admin: MD5:21232f297a57a5a743894a0e4a801fc3, admin

cd $LAUNCH_DIR
