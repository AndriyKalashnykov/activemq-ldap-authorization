#!/bin/bash

ACTIVEMQ_BASE=/opt/apache-activemq-5.16.1
JETTY_REALM_FILE=$ACTIVEMQ_BASE/conf/jetty-realm.properties
CONF_FILE=$ACTIVEMQ_BASE/conf/activemq.xml

if [ ! -z "$ADMIN_PASSWORD" ];then
    sed -i "s/^admin:.*/admin: $ADMIN_PASSWORD, admin/" $JETTY_REALM_FILE
fi

if [ ! -z "$USER_PASSWORD" ];then
    sed -i "s/^user:.*/user: $USER_PASSWORD, user/" $JETTY_REALM_FILE
fi

if [ ! -z "$PERCENT_JVM_HEAP" ];then
    sed -i "s#<memoryUsage percentOfJvmHeap=.*#<memoryUsage percentOfJvmHeap="$PERCENT_JVM_HEAP" />#" $CONF_FILE
fi

if [ ! -z "$STORE_USAGE" ];then
    sed -i "s#<storeUsage limit=.*#<storeUsage limit="$STORE_USAGE" />#" $CONF_FILE
fi

if [ ! -z "$TEMP_USAGE" ];then
    sed -i "s#<tempUsage limit=.*#<tempUsage limit="$TEMP_USAGE" />#" $CONF_FILE
fi

set -x

# lsof -i:389
# netstat -anp tcp | grep LISTEN | grep 389
# nmap -sT -O localhost | grep 389

# cat /opt/apache-activemq-5.16.1/conf/login.config
# cat /opt/apache-activemq-5.16.1/conf/activemq.xml
# cat /opt/apache-activemq-5.16.1/conf/jetty.xml

$ACTIVEMQ_BASE/bin/activemq start && tail -f /opt/apache-activemq-5.16.1/data/activemq.log