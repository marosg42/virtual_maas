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
    command = "sudo snap install --channel ${var.juju_channel} --classic juju || sudo snap refresh --channel ${var.juju_channel} --classic juju"
  }
}

resource "null_resource" "juju_bootstrap" {
  depends_on = [null_resource.juju_install]

  provisioner "local-exec" {
    environment = {
      MAAS_URL     = local.maas_url
      MAAS_API_KEY = var.maas_api_key
    }
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      SSH_KEY=$(eval echo "${var.ssh_private_key_path}")
      test -f "$SSH_KEY" || ssh-keygen -b 2048 -t rsa -f "$SSH_KEY" -q -N ""

      python3 ${path.module}/write_juju_config.py

      juju add-cloud maas_cloud ~/juju_maas_cloud.yaml --client 2>/dev/null || \
        juju update-cloud maas_cloud --client -f ~/juju_maas_cloud.yaml
      juju add-credential maas_cloud -f ~/juju_maas_credentials.yaml --client 2>/dev/null || true
      juju controllers --format json 2>/dev/null | jq -e '.controllers["juju-controller"]' > /dev/null 2>&1 || \
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
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      DEADLINE=$(( $(date +%s) + 1800 ))
      if [[ ${local.juju_major} -eq 3 ]]; then
        # Skip if already HA
        [[ $(juju controllers --refresh --format json | jq '.controllers[.["current-controller"]]["controller-machines"].Active') == "3" ]] && exit 0
        juju enable-ha
        until [[ $(juju controllers --refresh --format json | jq '.controllers[.["current-controller"]]["controller-machines"].Active') == "3" ]]; do
          [[ $(date +%s) -ge $DEADLINE ]] && echo "Timeout waiting for Juju HA" && exit 1
          sleep 10
        done
      else
        # Skip if already HA
        [[ $(juju status -m controller --format json | jq '[.machines[] | select(."controller-member-status" == "has-vote")] | length') -eq 3 ]] && exit 0
        juju spaces -m controller --format yaml
        sleep 10
        juju bind -m controller controller space-generic || true
        # Only add units if fewer than 3 exist
        UNIT_COUNT=$(juju status -m controller --format json | jq '[.applications.controller.units | keys[]] | length')
        [[ $UNIT_COUNT -lt 3 ]] && juju add-unit -m controller controller -n $(( 3 - $UNIT_COUNT ))
        until [[ $(juju status -m controller --format json | jq '[.machines[] | select(."controller-member-status" == "has-vote")] | length') -eq 3 ]]; do
          [[ $(date +%s) -ge $DEADLINE ]] && echo "Timeout waiting for Juju HA" && exit 1
          sleep 10
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
