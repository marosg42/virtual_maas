#!/bin/bash -exu

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $SCRIPT_DIR

terragrunt --non-interactive run-all apply || exit 1

./test-juju.sh
