#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd $SCRIPT_PARENT_DIR

docker run --rm -d -p 389:389 -p 636:636 -v $(PWD)/ldif-openldap:/container/service/slapd/assets/config/bootstrap/ldif/custom -e LDAP_DOMAIN=activemq.apache.org -e LDAP_ORGANISATION="Apache ActiveMQ Test Org" -e LDAP_ROOTPASS=admin --name openldap osixia/openldap:1.2.1 --copy-service

docker exec -it openldap ls /container/service/slapd/assets/config/bootstrap/ldif/custom

cd $LAUNCH_DIR