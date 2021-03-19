#!/bin/bash

# set -x

LAUNCH_DIR=$(pwd); SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd $SCRIPT_DIR; cd ..; SCRIPT_PARENT_DIR=$(pwd);
. $SCRIPT_DIR/set-env.sh

PWD=${1:-admin}
ALG=${2:-SHA}

PWD_HASH=$(docker exec $OPENLDAP_CONTAINER slappasswd -h {$ALG} -s $PWD)
echo "PWD: $PWD, PWD_HASH: $PWD_HASH, ALG: $ALG,"

cd $LAUNCH_DIR
