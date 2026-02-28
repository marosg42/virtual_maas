terraform {
  required_version = ">= 1.0"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "2.3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

locals {
  maas_url   = "http://${var.maas_controller_ip_address}:5240/MAAS"
  juju_major = tonumber(regex("^(\\d+)", var.juju_channel)[0])
}

resource "null_resource" "juju_install" {
  provisioner "local-exec" {
    command = "sudo snap install --channel ${var.juju_channel} juju || sudo snap refresh --channel ${var.juju_channel} juju"
  }
}

resource "null_resource" "juju_bootstrap" {
  depends_on = [null_resource.juju_install]

  provisioner "local-exec" {
    environment = {
      MAAS_URL     = local.maas_url
      MAAS_API_KEY = var.maas_api_key
    }
    command = <<-EOT
      set -e

      SSH_KEY=$(eval echo "${var.ssh_private_key_path}")
      test -f "$SSH_KEY" || ssh-keygen -b 2048 -t rsa -f "$SSH_KEY" -q -N ""

      python3 - << 'PYEOF'
import os

home        = os.path.expanduser("~")
maas_url    = os.environ["MAAS_URL"]
maas_api_key = os.environ["MAAS_API_KEY"]

with open(f"{home}/juju_maas_cloud.yaml", "w") as f:
    f.write(f"""clouds:
    maas_cloud:
        type: maas
        auth-types: [oauth1]
        endpoint: {maas_url}
        regions:
            default:
                endpoint: {maas_url}
""")

with open(f"{home}/juju_maas_credentials.yaml", "w") as f:
    f.write(f"""credentials:
    maas_cloud:
        maas_cloud_credentials:
            auth-type: oauth1
            maas-oauth: {maas_api_key}
""")
os.chmod(f"{home}/juju_maas_credentials.yaml", 0o600)

with open(f"{home}/juju_model_defaults.yaml", "w") as f:
    f.write(
        'cloudinit-userdata: "write_files:\\n  - content: |\\n      kernel.keys.maxkeys = 2000\\n'
        '    owner: \\"root:root\\"\\n    path: /etc/sysctl.d/10-maxkeys.conf\\n'
        '    permissions: \\"0644\\"\\npostruncmd:\\n  - sysctl --system\\n"\n'
        "juju-no-proxy: 10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,127.0.0.1,localhost\n"
        "logging-config: <root>=DEBUG\n"
    )
PYEOF

      juju add-cloud maas_cloud ~/juju_maas_cloud.yaml --client
      juju add-credential maas_cloud -f ~/juju_maas_credentials.yaml --client
      juju bootstrap \
        --bootstrap-constraints "arch=amd64 tags=juju" \
        --config caas-image-repo=ghcr.io/juju \
        --config bootstrap-timeout=1800 \
        --model-default ~/juju_model_defaults.yaml \
        maas_cloud juju-controller
    EOT
  }
}

resource "null_resource" "juju_ha" {
  count      = var.juju_nodes_count == 3 ? 1 : 0
  depends_on = [null_resource.juju_bootstrap]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      MAX_WAIT=1800
      SLEEP=10
      ELAPSED=0
      if [[ ${local.juju_major} -eq 3 ]]; then
        juju enable-ha
        until [[ $(juju controllers --refresh --format json | jq '.controllers[.["current-controller"]]["controller-machines"].Active') == "3" ]]; do
          [[ $ELAPSED -ge $MAX_WAIT ]] && echo "Timeout waiting for Juju HA" && exit 1
          sleep $SLEEP; ELAPSED=$((ELAPSED + SLEEP))
        done
      else
        juju spaces -m controller --format yaml
        sleep 10
        juju bind -m controller controller space-generic
        juju add-unit -m controller controller -n 2
        until [[ $(juju status -m controller --format json | jq '[.machines[] | select(."controller-member-status" == "has-vote")] | length') -eq 3 ]]; do
          [[ $ELAPSED -ge $MAX_WAIT ]] && echo "Timeout waiting for Juju HA" && exit 1
          sleep $SLEEP; ELAPSED=$((ELAPSED + SLEEP))
        done
      fi
    EOT
  }
}

data "external" "juju_version_info" {
  depends_on = [null_resource.juju_install]
  program    = ["bash", "-c", <<-EOT
    VER=$(juju version)
    MAJOR=$(echo "$VER" | grep -oP '^\d+')
    jq -n --arg snap_version "$VER" --arg major "$MAJOR" '{"snap_version": $snap_version, "major": $major}'
  EOT
  ]
}
