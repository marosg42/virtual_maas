#!/bin/bash -eux

# Get the number of juju nodes from terraform
JUJU_NODE_COUNT=$(cd units/virtualnodes && terragrunt output -json juju_nodes | jq 'length')
if [[ $JUJU_NODE_COUNT -eq 0 ]]; then
    echo "No Juju units defined"
    exit 1
fi

juju controllers --refresh
juju add-model test
juju deploy --force --channel 16/edge  -n 3 postgresql
juju deploy -n 3 ubuntu
sleep 600
juju status
juju status -m controller
for i in {1..20} ; do for j in 0 1 2; do juju exec --unit ubuntu/$j date ; done ; done
juju status
juju status -m controller
time juju destroy-model --no-prompt test
juju status
juju status -m controller
