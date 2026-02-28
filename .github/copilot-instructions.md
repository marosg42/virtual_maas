# Copilot Instructions

## Overview

This repo provisions a virtual MAAS (Metal as a Service) environment on a Linux KVM hypervisor using **Terragrunt** + **OpenTofu**. It spins up a MAAS controller VM, worker nodes, and optional Juju controller nodes, then registers all VMs with MAAS via the `canonical/maas` Terraform provider.

## Key Commands

```bash
# Install dependencies (terragrunt, opentofu, terraform, libvirt tools)
./install_deps.sh

# Deploy all units and run Juju tests
./deploy.sh

# Plan/apply a single unit without affecting others
cd units/<unit> && terragrunt plan
cd units/<unit> && terragrunt apply

# Apply the full stack
terragrunt --non-interactive run-all apply

# Submit a CI job via Testflinger
./local-testflinger.sh lp:username   # or gh:username
```

## Architecture

Terragrunt units in `units/` deploy in strict dependency order defined in `stack.hcl`:

```
bridge → virtualnodes → maas → juju_controller
```

- **bridge**: Creates `maasbr0` Linux bridge + VLAN sub-interfaces (`vlan101br`, `vlan102br`, etc.) with NAT/iptables rules using `local-exec`. Not persistent across reboots.
- **virtualnodes**: Provisions libvirt VMs — a MAAS controller (cloud-init bootstrapped), worker nodes (PXE-boot only, `running = false`), and optional Juju nodes. Waits for `/tmp/.i_am_done` on the MAAS controller before completing. Retrieves the MAAS API key via SSH and writes it to `~/api.key`.
- **maas**: Configures MAAS fabrics, VLANs, subnets, IP ranges, DHCP, and registers VMs as `maas_machine` resources with virsh power control. Generates its `provider.tf` dynamically from `templates/maas-provider.tf.tpl` using outputs from the `virtualnodes` unit.
- **juju_controller**: Installs the Juju snap, bootstraps a Juju controller on MAAS (constrained to nodes tagged `juju`), and optionally enables HA when `juju_nodes_count == 3`. The Juju channel is controlled by `juju_channel` in `stack.hcl` (e.g. `4.0/stable`). Outputs `juju_snap_version` and `juju_major_version`. MAAS credentials come from the `maas` unit outputs — they are not configurable independently.

## Stack Configuration (`stack.hcl`)

`stack.hcl` at the repo root is the single source of truth for stack-wide variables (SSH key paths, VM sizing, node counts). Each unit's `terragrunt.hcl` inherits from it via:

```hcl
include "stack" {
  path   = find_in_parent_folders("stack.hcl")
  expose = true
}

inputs = merge(include.stack.locals.stack_config, { ... })
```

To change VM sizes or node counts, edit `stack.hcl`.

## Key Conventions

- **`juju_nodes_count` must be 0, 1, or 3** — enforced by a Terraform `validation` block in `units/virtualnodes/variables.tf`.
- **`juju_channel` controls the Juju snap** (e.g. `4.0/stable`, `3/stable`) — set in `stack.hcl`. The major version is derived from it at plan time to select the correct HA path (`juju enable-ha` for v3, `juju add-unit -n 2` for v4).
- **SSH key at `~/.ssh/passwordless`** (no passphrase) — required for provisioner SSH connections to the MAAS controller. Created automatically by `test-juju.sh` if missing.
- **MAC addresses are hardcoded** per VM type in `units/virtualnodes/main.tf`:
  - Worker nodes: `AA:BB:CC:11:22:<index+10>`
  - Juju nodes: `AA:BB:CC:55:66:<index+10>`
  - MAAS controller: `AA:BB:CC:11:11:02` / `AA:BB:CC:11:11:03`
- **The `maas` unit's `provider.tf` is generated** — never edit `units/maas/provider.tf` directly; it is overwritten by `terragrunt generate` on every run.
- **The `maas` unit connects to libvirt over SSH** (`qemu+ssh://USER@172.16.1.1/system`) because MAAS must reach the KVM host to manage VM power — `172.16.1.1` is the hardcoded bridge gateway.
- **Mock outputs** in `terragrunt.hcl` dependency blocks allow `terragrunt plan`/`validate` on a single unit without running its dependencies first.
- **Disk sizes** are specified in bytes in variables (e.g., `21474836480` = 20 GiB).
- **`local-exec` provisioners must specify `interpreter = ["/bin/bash", "-c"]`** — OpenTofu defaults to `/bin/sh`, which doesn't support `[[`, process substitution, or other bash-isms used in this repo.
- **The Juju snap cannot read `/tmp`** due to snap confinement — config files written for `juju add-cloud`/`add-credential` must be placed in `$HOME`.

## Network Layout

| Network | CIDR | Interface | Purpose |
|---|---|---|---|
| Bridge base | 172.16.0.0/24 | `maasbr0` | Host bridge |
| generic_net | 172.16.1.0/24 | `vlan101br` | PXE/MAAS management |
| external_net | 172.16.2.0/24 | `vlan102br` | External/API access |

The generic subnet DHCP range is `.200–.254`; reserved ranges cover `.1–.5`, `.10–.29` (internal API), `.30–.49` (public API).

## CI (Testflinger)

`local-testflinger.sh` packages the repo as `repository.tar.gz`, injects variables into `testflinger/job.yaml.tpl` via `envsubst`, and submits the job. The job provisions a bare-metal host, copies the tarball, and runs `install_deps.sh` + `deploy.sh` remotely.
