#!/bin/bash
# Templating entrypoint for the hawtio console (mirrors the broker's init.sh):
# substitute the ##### TOKEN ##### placeholders in login.config from env vars,
# then run Tomcat in the foreground. hawtio authenticates against the resulting
# LDAPLogin realm (the same org.apache.activemq.jaas.LDAPLoginModule the broker
# uses), so console access is gated by the same LDAP directory.
set -eu

LOGIN_CONF="${CATALINA_HOME}/conf/login.config"

# Defaults mirror 6.2.6/.env so the container works without an explicit env.
: "${LDAP_HOST:=openldap}"
: "${LDAP_PORT:=389}"
: "${LDAP_CONN_USER:=cn=admin,dc=activemq,dc=apache,dc=org}"
: "${LDAP_CONN_USER_PWD:=admin}"
: "${LDAP_USER_BASE:=ou=User,ou=ActiveMQ,dc=activemq,dc=apache,dc=org}"
: "${LDAP_ROLE_BASE:=ou=Group,ou=ActiveMQ,dc=activemq,dc=apache,dc=org}"

sed -i \
  -e "s|##### LDAP_HOST #####|${LDAP_HOST}|g" \
  -e "s|##### LDAP_PORT #####|${LDAP_PORT}|g" \
  -e "s|##### LDAP_CONN_USER #####|${LDAP_CONN_USER}|g" \
  -e "s|##### LDAP_CONN_USER_PWD #####|${LDAP_CONN_USER_PWD}|g" \
  -e "s|##### LDAP_USER_BASE #####|${LDAP_USER_BASE}|g" \
  -e "s|##### LDAP_ROLE_BASE #####|${LDAP_ROLE_BASE}|g" \
  "$LOGIN_CONF"

echo "###################################### hawtio login.config ######################################"
cat "$LOGIN_CONF"
echo "#################################################################################################"

exec catalina.sh run
