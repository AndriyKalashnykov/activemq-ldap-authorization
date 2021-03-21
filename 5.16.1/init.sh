#!/bin/bash

ACTIVEMQ_BASE=/opt/apache-activemq-5.16.1
JETTY_REALM_FILE=$ACTIVEMQ_BASE/conf/jetty-realm.properties
ACTIVEMQ_CONF_FILE=$ACTIVEMQ_BASE/conf/activemq.xml
LOGIN_CONF_FILE=$ACTIVEMQ_BASE/conf/login.config
ACTIVEMQ_ENV=$ACTIVEMQ_BASE/bin/env

[[ $DEBUG == true ]] && set -x

sed -i "s|##### STORE_USAGE #####|${storeUsage}|" "$CONFIG_FILE"

if [ ! -z "$LDAP_HOST" ];then
     sed -i "s|##### LDAP_HOST #####|${LDAP_HOST}|" $ACTIVEMQ_CONF_FILE
     sed -i "s|##### LDAP_HOST #####|${LDAP_HOST}|" $LOGIN_CONF_FILE
fi

if [ ! -z "$LDAP_PORT" ];then
     sed -i "s|##### LDAP_PORT #####|${LDAP_PORT}|" $ACTIVEMQ_CONF_FILE
     sed -i "s|##### LDAP_PORT #####|${LDAP_PORT}|" $LOGIN_CONF_FILE
fi

if [ ! -z "$PERCENT_JVM_HEAP" ];then
    sed -i "s|##### PERCENT_JVM_HEAP #####|${PERCENT_JVM_HEAP}|" $ACTIVEMQ_CONF_FILE
fi

if [ ! -z "$STORE_USAGE" ];then
    sed -i "s|##### STORE_USAGE #####|${STORE_USAGE}|" $ACTIVEMQ_CONF_FILE
fi

if [ ! -z "$TEMP_USAGE" ];then
    sed -i "s|##### STEMP_USAGE #####|${TEMP_USAGE}|" $ACTIVEMQ_CONF_FILE
fi

[[ -n ${ACTIVEMQ_OPTS_MEMORY} ]] && sed -ri "s/^(ACTIVEMQ_OPTS_MEMORY=).*/\1\"${ACTIVEMQ_OPTS_MEMORY}\"/" ${ACTIVEMQ_ENV}

echo "###################################### activemq.xml ######################################"
cat $LOGIN_CONF_FILE

echo "###################################### login.config ######################################"
cat $ACTIVEMQ_CONF_FILE

# $ACTIVEMQ_BASE/bin/activemq console
$ACTIVEMQ_BASE/bin/activemq start && tail -f /opt/activemq/data/activemq.log