#!/bin/bash -exu

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $SCRIPT_DIR

terragrunt --non-interactive run-all apply || exit 1

export TEST_MAAS_API_KEY="$(cat ~/api.key)"
export TEST_MAAS_URL=http://172.16.1.2:5240/MAAS

export TEST_JUJU_CHANNEL=4.0/stable
./test-juju4.sh
