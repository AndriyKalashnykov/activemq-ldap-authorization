#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

# docker exec -it $ACTIVEMQ_CONTAINER /bin/bash

# QUEUES
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user admin --password admin --destination queue://TEST --message hello --messageCount 1
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user user --password admin --destination queue://USERS.TEST --message hello --messageCount 1
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user admin --password admin --destination queue://ADMINS.TEST --message hello --messageCount 1
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user user --password admin --destination queue://ADMINS.TEST --message hello --messageCount 1

# TOPICS
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user admin --password admin --destination topic://TEST --message hello --messageCount 1
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user admin --password admin --destination topic://ADMINS.TEST --message hello --messageCount 1
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user user --password admin --destination topic://USERS.TEST --message hello --messageCount 1
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user user --password admin --destination topic://ADMINS.TEST --message hello --messageCount 1
cd $LAUNCH_DIR
