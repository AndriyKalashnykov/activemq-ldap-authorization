#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);

cd /opt/apache-activemq-5.16.1/bin

./activemq start && tail -f /opt/apache-activemq-5.16.1/data/activemq.log
