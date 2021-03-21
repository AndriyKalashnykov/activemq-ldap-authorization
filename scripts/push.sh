#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

cd $ACTIVEMQ_VER

docker login --username=${DOCKER_LOGIN} --password ${DOCKER_PWD} ${DOCKER_REGISTRY}
docker push ${DOCKER_LOGIN}/$ACTIVEMQ_IMAGE_NAME:$ACTIVEMQ_VER

docker push ${DOCKER_LOGIN}/$APACHEDS_IMAGE_NAME:$APACHEDS_VER

cd $LAUNCH_DIR
