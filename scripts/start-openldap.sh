#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

cd $SCRIPT_PARENT_DIR

# https://activemq.apache.org/cached-ldap-authorization-module
# https://svn.apache.org/repos/asf/activemq/trunk/activemq-unit-tests/src/test/resources/org/apache/activemq/security/activemq-openldap.ldif

# Minimal OpenLDAP image built from Symas's maintained packages (openldap/Dockerfile).
# Suffix dc=activemq,dc=apache,dc=org is derived from LDAP_DOMAIN; the seed LDIF
# under openldap/ldif is slapadd'd from /seed at startup.

# 1
docker build -t "${OPENLDAP_IMAGE:-activemq-openldap:latest}" "$SCRIPT_PARENT_DIR/openldap"
docker run -d --rm --hostname $OPENLDAP_CONTAINER --name $OPENLDAP_CONTAINER -p 389:389 -p 636:636 -v "$(pwd)/openldap/ldif":/seed:ro -e LDAP_DOMAIN=activemq.apache.org -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ADMIN_PASSWORD=admin "${OPENLDAP_IMAGE:-activemq-openldap:latest}"
OPENLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" $OPENLDAP_CONTAINER)
echo "OPENLDAP_IP: https://$OPENLDAP_IP:389"

# https://github.com/osixia/docker-phpLDAPadmin

# Maintained leenooks phpLDAPadmin v2 (HTTP on 8080); point it at the OpenLDAP container.
docker run --rm -d --hostname $PHPLDAPADMIN_CONTAINER --name $PHPLDAPADMIN_CONTAINER --link $OPENLDAP_CONTAINER -p 6443:8080 --env LDAP_HOST="ldap://$OPENLDAP_CONTAINER:389" --detach phpldapadmin/phpldapadmin:2.3.11
PHPLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" phpldapadmin)
# echo "PHPLDAP_IP: https://$PHPLDAP_IP"
echo "PHPLDAP_IP: http://localhost:6443"
echo "Login DN: cn=admin,dc=activemq,dc=apache,dc=org"
echo "Password: admin"

# echo http://localhost:8080

# 2
# docker run --rm -d -p 389:389 -p 636:636 -v $(pwd)/ldif-openldap-activemq-example:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=acme.com -e LDAP_BASE_DN="dc=acme,dc=com" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap osixia/openldap:1.5.0 --copy-service

# 3
# docker run --rm -p 389:389 -p 636:636 -v $(pwd)/ldif-activemq58:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=ActiveMQ.system -e LDAP_BASE_DN="o=ActiveMQ,ou=system" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=secret --name openldap osixia/openldap:1.5.0 --copy-service

docker exec -it $OPENLDAP_CONTAINER ls /seed

cd $LAUNCH_DIR
