#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

CONTAINER=openldap
OPENLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" $CONTAINER)
if [ -z $OPENLDAP_IP ]; then
    OPENLDAP_IP=$(docker ps -q | xargs -n 1 docker inspect --format '{{ .Name }} {{range .NetworkSettings.Networks}} {{.IPAddress}}{{end}}' | sed 's#^/##' | grep $CONTAINER | awk '{print $2}')
else  
    echo ""
fi
    
echo $OPENLDAP_IP

docker run --rm --name activemq -p 1883:1883 -p 5672:5672 -p 8161:8161 -p 61613:61613 -p 61614:61614 -p 61616:61616 \
    -e LDAP_HOST=$OPENLDAP_IP \
    -e LDAP_PORT=389 \
    -e PERCENT_JVM_HEAP=75 \
    -e STORE_USAGE="90 gb" \
    -e TEMP_USAGE="45 gb" \
    ${DOCKER_LOGIN}/$IMAGE_NAME:$ACTIVEMQ_VER

ACTIVEMQ_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" activemq)

echo "open http://$ACTIVEMQ_IP:8161/admin"    

# docker exec -it activemq /bin/bash
# docker exec -it activemq /opt/apache-activemq-5.16.1/bin/activemq producer --messageCount 1 --user admin --password admin
docker exec -it activemq /opt/apache-activemq-5.16.1/bin/activemq producer --user admin --password admin --destination TEST --message hello --messageCount 1
docker exec -it activemq /opt/apache-activemq-5.16.1/bin/activemq producer --user user --password admin --destination USERS.TEST --message hello --messageCount 1
docker exec openldap ldapsearch -x -H ldap://localhost:389 -b "cn=ActiveMQ.Advisory,ou=Topic,ou=Destination,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -s sub "(cn=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin

cd $LAUNCH_DIR
