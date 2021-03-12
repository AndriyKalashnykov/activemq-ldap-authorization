#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd $SCRIPT_PARENT_DIR

# 1
docker exec openldap slappasswd -h {SHA} -s admin
ldapwhoami -vvv -H ldap://localhost:389 -D "uid=admin,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -x -w admin
docker exec openldap ldapsearch -x -H ldap://localhost:389 -b ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost:389 -b cn=mqbroker,ou=Services,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost:389 -b ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost:389 -b ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(member:=uid=client,ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec openldap ldapsearch -x -H ldap://localhost:389 -b cn=ActiveMQ.Advisory.$,ou=Topic,ou=Destination,ou=ActiveMQ,dc=activemq,dc=apache,dc=org -s sub "(cn=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin

# 2
# docker exec openldap slappasswd -h {SHA} -s password
# ldapwhoami -vvv -H ldap://localhost:389 -D "cn=mqbroker,ou=Services,dc=acme,dc=com" -x -w admin
# ldapwhoami -vvv -H ldap://localhost:389 -D "uid=admin,ou=User,ou=ActiveMQ,ou=systems,dc=acme,dc=com" -x -w admin
# docker exec openldap ldapsearch -x -H ldap://localhost:389 -b ou=User,ou=ActiveMQ,ou=systems,dc=acme,dc=com -D "cn=mqbroker,ou=Services,dc=acme,dc=com" -w admin


cd $LAUNCH_DIR