#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

cd $SCRIPT_PARENT_DIR

ldapwhoami -vvv -H ldap://localhost:10389 -D "cn=mqbroker,ou=Services,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -x -w admin
ldapwhoami -vvv -H ldap://localhost:10389 -D "uid=admin,ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -x -w admin

ldapsearch -x -H ldap://localhost:10389 -b "ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -D "cn=mqbroker,ou=Services,ou=ActiveMQ,dc=activemq,dc=apache,dc=org" -w admin

cd $LAUNCH_DIR
