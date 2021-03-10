#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd $SCRIPT_PARENT_DIR

docker exec openldap ldapsearch -x -H ldap://localhost -b ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost -b cn=mqbroker,ou=Services,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost -b ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost -b ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(member:=uid=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost -b cn=ActiveMQ.Advisory.$,ou=Topic,ou=Destination,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(cn=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin

cd $LAUNCH_DIR