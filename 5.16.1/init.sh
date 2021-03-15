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
    sed -i "s#<memoryUsage percentOfJvmHeap=.*#<memoryUsage percentOfJvmHeap="$PERCENT_JVM_HEAP" />#" $ACTIVEMQ_CONF_FILE
fi

if [ ! -z "$STORE_USAGE" ];then
    sed -i "s#<storeUsage limit=.*#<storeUsage limit="$STORE_USAGE" />#" $ACTIVEMQ_CONF_FILE
fi

if [ ! -z "$TEMP_USAGE" ];then
    sed -i "s#<tempUsage limit=.*#<tempUsage limit="$TEMP_USAGE" />#" $ACTIVEMQ_CONF_FILE
fi

cat $ACTIVEMQ_CONF_FILE | grep ldap:
cat $LOGIN_CONF_FILE | grep ldap:

$ACTIVEMQ_BASE/bin/activemq start && tail -f /opt/apache-activemq-$ACTIVEMQ_BASE/data/activemq.log