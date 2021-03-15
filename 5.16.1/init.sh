#!/bin/bash

ACTIVEMQ_BASE=/opt/apache-activemq-5.16.1
JETTY_REALM_FILE=$ACTIVEMQ_BASE/conf/jetty-realm.properties
ACTIVEMQ_CONF_FILE=$ACTIVEMQ_BASE/conf/activemq.xml
LOGIN_CONF_FILE=$ACTIVEMQ_BASE/conf/login.config

if [ ! -z "$LDAP_HOST" ];then
     sed -i "s#__LDAP_HOST__#"$LDAP_HOST"#" $ACTIVEMQ_CONF_FILE
     sed -i "s#__LDAP_HOST__#"$LDAP_HOST"#" $LOGIN_CONF_FILE
fi

if [ ! -z "$LDAP_PORT" ];then
    sed -i "s#__LDAP_PORT__#"$LDAP_PORT"#" $ACTIVEMQ_CONF_FILE
    sed -i "s#__LDAP_PORT__#"$LDAP_PORT"#" $LOGIN_CONF_FILE
fi

if [ ! -z "$PERCENT_JVM_HEAP" ];then
    sed -i "s#__PERCENT_JVM_HEAP__#"$PERCENT_JVM_HEAP"#" $ACTIVEMQ_CONF_FILE
fi

if [ ! -z "$STORE_USAGE" ];then
    sed -i "s#__STORE_USAGE__#"$STORE_USAGE"#" $ACTIVEMQ_CONF_FILE
fi

if [ ! -z "$TEMP_USAGE" ];then
    sed -i "s#__TEMP_USAGE__#"$TEMP_USAGE"#" $ACTIVEMQ_CONF_FILE
fi

echo "###################################### activemq.xml ######################################"
cat $LOGIN_CONF_FILE

echo "###################################### login.config ######################################"
cat $ACTIVEMQ_CONF_FILE


$ACTIVEMQ_BASE/bin/activemq start && tail -f /opt/activemq/data/activemq.log