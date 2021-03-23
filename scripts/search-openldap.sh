#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

cd $SCRIPT_PARENT_DIR

# verify password
ldapwhoami -vvv -H ldap://localhost:389 -D "uid=admin,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -x -w admin
ldapwhoami -vvv -H ldap://localhost:389 -D "uid=user,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -x -w admin
ldapwhoami -vvv -H ldap://localhost:389 -D "cn=mqbroker,ou=Services,dc=activemq,dc=apache,dc=org" -x -w admin

docker exec $OPENLDAP_CONTAINER ldapsearch -x -H ldap://localhost:389 -b "ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec $OPENLDAP_CONTAINER ldapsearch -x -H ldap://localhost:389 -b "cn=mqbroker,ou=Services,dc=activemq,dc=apache,dc=org" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec $OPENLDAP_CONTAINER ldapsearch -x -H ldap://localhost:389 -b "ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec $OPENLDAP_CONTAINER ldapsearch -x -H ldap://localhost:389 -b "ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -s sub "(member=uid=user)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec $OPENLDAP_CONTAINER ldapsearch -x -H ldap://localhost:389 -b "cn=ActiveMQ.Advisory.$,ou=Topic,ou=Destination,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -s sub "(cn=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
docker exec $OPENLDAP_CONTAINER ldapsearch -x -H ldap://localhost:389 -b "cn=ActiveMQ.Advisory,ou=Topic,ou=Destination,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -s sub "(cn=admin)" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin

# TLS
# enable self-signed the hard way
# sudo sh -c "echo 'TLS_REQCERT never' >> /etc/ldap/ldap.conf"
# or not so much LDAPTLS_REQCERT=never 
LDAPTLS_REQCERT=never ldapsearch -x -H ldaps://localhost:636 -b "ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -D "cn=admin,dc=activemq,dc=apache,dc=org" -w admin
yes | openssl s_client -connect localhost:636 -showcerts

cd $LAUNCH_DIR
