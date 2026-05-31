#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

. $SCRIPT_DIR/set-env.sh

cd /opt/apache-activemq-${ACTIVEMQ_VER}/bin

./activemq start && tail -f /opt/apache-activemq-${ACTIVEMQ_VER}/data/activemq.log
