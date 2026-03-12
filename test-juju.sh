#!/bin/bash 

# Get the number of juju nodes from terraform
JUJU_NODE_COUNT=$(cd units/virtualnodes && terragrunt output -json juju_nodes | jq 'length')
if [[ $JUJU_NODE_COUNT -eq 0 ]]; then
    echo "No Juju units defined"
    exit 1
fi

juju add-model test

ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' > /dev/null 2>&1
juju add-ssh-key "$(cat ~/.ssh/id_ed25519.pub)"
juju model-config -m test default-space=space-generic || true

juju deploy postgresql -n 3 --channel 16/edge --force

echo "sleep for 60 seconds"
sleep 60
juju status
juju status -m controller
echo "sleep for 20 minutes"
sleep 1200
juju status
juju status -m controller
for i in {1..20} ; do for j in 0 1 2; do juju exec --unit postgresql/$j date ; done ; done
time juju destroy-model --no-prompt test
