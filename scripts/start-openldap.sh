#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

cd $SCRIPT_PARENT_DIR

# https://activemq.apache.org/cached-ldap-authorization-module
# https://svn.apache.org/repos/asf/activemq/trunk/activemq-unit-tests/src/test/resources/org/apache/activemq/security/activemq-openldap.ldif

# https://github.com/osixia/docker-openldap
# https://github.com/osixia/docker-openldap/blob/master/example/docker-compose.yml

# 1
docker run -d --rm --hostname $OPENLDAP_CONTAINER --name $OPENLDAP_CONTAINER -p 389:389 -p 636:636 -v "$(pwd)/openldap/ldif":/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=activemq.apache.org -e LDAP_BASE_DN="dc=activemq,dc=apache,dc=org" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin -e LDAP_TLS_VERIFY_CLIENT=never -e LDAP_TLS_CIPHER_SUITE=SECURE256:+SECURE128:+VERS-TLS-ALL:+VERS-TLS1.2:+RSA:+DHE-DSS:+CAMELLIA-128-CBC:+CAMELLIA-256-CBC osixia/openldap:1.5.0 --copy-service
OPENLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" $OPENLDAP_CONTAINER)
echo "OPENLDAP_IP: https://$OPENLDAP_IP:389"

# https://github.com/osixia/docker-phpLDAPadmin

# --env PHPLDAPADMIN_LDAP_HOSTS="[{'$OPENLDAP_CONTAINER': [{'server': [{'port': 389}]}]}]" -d osixia/phpldapadmin
docker run --rm -d --hostname $PHPLDAPADMIN_CONTAINER --name $PHPLDAPADMIN_CONTAINER --link $OPENLDAP_CONTAINER -p 8080:80 -p 6443:443 --env PHPLDAPADMIN_LDAP_HOSTS=$OPENLDAP_CONTAINER --detach osixia/phpldapadmin:0.9.0
PHPLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" phpldapadmin)
# echo "PHPLDAP_IP: https://$PHPLDAP_IP"
echo "PHPLDAP_IP: https://localhost:6443"
echo "Login DN: cn=admin,dc=activemq,dc=apache,dc=org"
echo "Password: admin"

# echo http://localhost:8080

# 2
# docker run --rm -d -p 389:389 -p 636:636 -v $(pwd)/ldif-openldap-activemq-example:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=acme.com -e LDAP_BASE_DN="dc=acme,dc=com" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap osixia/openldap:1.5.0 --copy-service

# 3
# docker run --rm -p 389:389 -p 636:636 -v $(pwd)/ldif-activemq58:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=ActiveMQ.system -e LDAP_BASE_DN="o=ActiveMQ,ou=system" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=secret --name openldap osixia/openldap:1.5.0 --copy-service

docker exec -it $OPENLDAP_CONTAINER ls /container/service/slapd/assets/config/bootstrap/ldif/custom

cd $LAUNCH_DIR
