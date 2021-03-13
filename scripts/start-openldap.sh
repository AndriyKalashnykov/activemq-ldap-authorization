#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd $SCRIPT_PARENT_DIR

# https://activemq.apache.org/cached-ldap-authorization-module
# https://svn.apache.org/repos/asf/activemq/trunk/activemq-unit-tests/src/test/resources/org/apache/activemq/security/activemq-openldap.ldif
# https://github.com/osixia/docker-openldap

# 1
docker run --rm -d --hostname openldap -p 389:389 -p 636:636 -v $(pwd)/ldif-openldap:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=activemq.apache.org -e LDAP_BASE_DN="dc=activemq,dc=apache,dc=org" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap osixia/openldap:1.5.0 --copy-service

# https://github.com/osixia/docker-phpLDAPadmin
# --env PHPLDAPADMIN_LDAP_HOSTS=127.0.0.1.xip.io 
docker run --rm -d --hostname phpldapadmin --name phpldapadmin --link openldap -p 8080:80 -p 6443:443 --env PHPLDAPADMIN_LDAP_HOSTS=openldap --detach osixia/phpldapadmin:latest
PHPLDAP_IP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" phpldapadmin)
echo "Go to: https://$PHPLDAP_IP"
# echo "Login DN: cn=admin,dc=activemq,dc=apache,dc=org"
# echo "Password: admin"
# open https://localhost:6443
# open http://localhost:8080

# 2
# docker run --rm -d -p 389:389 -p 636:636 -v $(pwd)/ldif-openldap-activemq-example:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=acme.com -e LDAP_BASE_DN="dc=acme,dc=com" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap osixia/openldap:1.5.0 --copy-service

# 3
# docker run --rm -p 389:389 -p 636:636 -v $(pwd)/ldif-activemq58:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=ActiveMQ.system -e LDAP_BASE_DN="o=ActiveMQ,ou=system" -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=secret --name openldap osixia/openldap:1.5.0 --copy-service

docker exec -it openldap ls /container/service/slapd/assets/config/bootstrap/ldif/custom

cd $LAUNCH_DIR
