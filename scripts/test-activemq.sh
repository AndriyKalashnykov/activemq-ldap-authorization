#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

# docker exec -it $ACTIVEMQ_CONTAINER /bin/bash
# docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --messageCount 1 --user admin --password admin
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user admin --password admin --destination TEST --message hello --messageCount 1
docker exec -it $ACTIVEMQ_CONTAINER /opt/apache-activemq-5.16.1/bin/activemq producer --user user --password admin --destination USERS.TEST --message hello --messageCount 1

cd $LAUNCH_DIR
