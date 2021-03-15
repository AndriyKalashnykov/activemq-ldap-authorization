#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

cd $ACTIVEMQ_VER

OPENLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" openldap)

docker run --rm --name activemq -p 1883:1883 -p 5672:5672 -p 8161:8161 -p 61613:61613 -p 61614:61614 -p 61616:61616 \
    -e LDAP_HOST=$OPENLDAP_IP \
    -e LDAP_PORT=389 \
    -e PERCENT_JVM_HEAP=75 \
    -e STORE_USAGE="90 gb" \
    -e TEMP_USAGE="45 gb" \
    ${DOCKER_LOGIN}/$IMAGE_NAME:$ACTIVEMQ_VER

echo "open http://$OPENLDAP_IP:8161"    

cd $LAUNCH_DIR
