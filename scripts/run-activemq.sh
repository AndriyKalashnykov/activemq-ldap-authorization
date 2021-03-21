#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh


OPENLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" $OPENLDAP_CONTAINER)
if [ -z $OPENLDAP_IP ]; then
    OPENLDAP_IP=$(docker ps -q | xargs -n 1 docker inspect --format '{{ .Name }} {{range .NetworkSettings.Networks}} {{.IPAddress}}{{end}}' | sed 's#^/##' | grep $OPENLDAP_CONTAINER | awk '{print $2}')
else  
    echo ""
fi
    
echo $OPENLDAP_IP

docker run --rm --name $ACTIVEMQ_CONTAINER -p 1883:1883 -p 5672:5672 -p 8161:8161 -p 61613:61613 -p 61614:61614 -p 61616:61616 \
    -e LDAP_HOST=$OPENLDAP_IP \
    -e LDAP_PORT=389 \
    -e PERCENT_JVM_HEAP=75 \
    -e STORE_USAGE="90 gb" \
    -e TEMP_USAGE="45 gb" \
    ${DOCKER_LOGIN}/$ACTIVEMQ_IMAGE_NAME:$ACTIVEMQ_VER

ACTIVEMQ_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" $ACTIVEMQ_CONTAINER)

echo "open http://$ACTIVEMQ_IP:8161/admin"    

cd $LAUNCH_DIR
