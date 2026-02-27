#!/bin/bash -eux

# Get the number of juju nodes from terraform
JUJU_NODE_COUNT=$(cd units/virtualnodes && terragrunt output -json juju_nodes | jq 'length')
if [[ $JUJU_NODE_COUNT -eq 0 ]]; then
    echo "No Juju units defined"
    exit 1
fi


# Controller bootstrap and HA setup are handled by the juju_controller Terraform unit.

juju controllers --refresh
juju add-model test
juju deploy --force --channel 16/edge  -n 3 postgresql
sleep 60
juju status
