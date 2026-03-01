# virtual_maas

Provisions a virtual MAAS (Metal as a Service) environment on a Linux KVM hypervisor using **Terragrunt** + **OpenTofu**. Spins up a MAAS controller VM, worker nodes, and optional Juju controller nodes, registers them all with MAAS, then bootstraps a Juju controller on top.

## Prerequisites

Run `./install_deps.sh` once on the KVM host to install:

- `terragrunt` (v0.87.1)
- `opentofu` (via apt)
- `terraform` (via HashiCorp apt repo — required by some providers)
- `libvirt` / `virsh` / `genisoimage`

## Quick start

```bash
./install_deps.sh
./deploy.sh
```

`deploy.sh` runs `terragrunt --non-interactive run-all apply` followed by `test-juju.sh` (post-bootstrap smoke tests).

## Unit dependency chain

Units are applied in this order, defined in `stack.hcl`:

```
bridge → virtualnodes → maas → juju_controller
```

| Unit | What it does |
|------|-------------|
| `bridge` | Creates `maasbr0` Linux bridge + VLAN sub-interfaces with NAT/iptables |
| `virtualnodes` | Provisions libvirt VMs (MAAS controller + worker nodes + optional Juju nodes) |
| `maas` | Configures MAAS (fabrics, VLANs, subnets, DHCP) and registers VMs |
| `juju_controller` | Installs Juju snap, bootstraps controller, optionally enables HA |

## Running units individually

Source the same environment variables that `deploy.sh` sets, then apply each unit:

```bash
export LIBVIRT_DEFAULT_URI="qemu:///system"

cd units/bridge          && terragrunt apply
cd ../virtualnodes       && terragrunt apply
cd ../maas               && terragrunt apply
cd ../juju_controller    && terragrunt apply
```

To inspect a plan without applying (works even when dependency outputs aren't available yet — uses mock outputs):

```bash
cd units/<unit> && terragrunt plan
```

To apply everything at once:

```bash
terragrunt --non-interactive run-all apply
```

## Configuration (`stack.hcl`)

All stack-wide variables live in `stack.hcl` at the repo root. Edit this file to change any of the values below — no individual unit files need to be touched.

| Variable | Default | Description |
|----------|---------|-------------|
| `ssh_private_key_path` | `~/.ssh/passwordless` | SSH key for provisioner connections to the MAAS controller VM. Created automatically on first bootstrap if missing. Must have no passphrase. |
| `ssh_public_key_path` | `~/.ssh/passwordless.pub` | Corresponding public key injected into VMs via cloud-init. |
| `libvirt_uri` | `qemu:///system` | Libvirt connection URI. Override via `LIBVIRT_DEFAULT_URI` env var. |
| `maas_hostname` | `maas-controller` | Hostname assigned to the MAAS controller VM. |
| `node_mem` | `8192` | RAM in MiB for each worker node. |
| `node_vcpu` | `4` | vCPUs for each worker node. |
| `maas_controller_mem` | `8192` | RAM in MiB for the MAAS controller VM. |
| `maas_controller_vcpu` | `4` | vCPUs for the MAAS controller VM. |
| `juju_channel` | `4.0/stable` | Juju snap channel (e.g. `3/stable`, `4.0/candidate`). Controls which Juju major version is installed and which HA path is taken. |
| `juju_nodes_count` | `3` | Number of Juju controller nodes. Must be **0**, **1**, or **3**. Use 3 for HA. |
| `juju_node_mem` | `4096` | RAM in MiB for each Juju node. |
| `juju_node_vcpu` | `2` | vCPUs for each Juju node. |

## Network layout

| Network | CIDR | Interface | Purpose |
|---------|------|-----------|---------|
| Bridge base | `172.16.0.0/24` | `maasbr0` | KVM host bridge |
| generic_net | `172.16.1.0/24` | `vlan101br` | PXE / MAAS management |
| external_net | `172.16.2.0/24` | `vlan102br` | External / API access |

DHCP range on `generic_net`: `.200–.254`. Reserved: `.1–.5`, `.10–.29` (internal API), `.30–.49` (public API).

## Remote deployment (Testflinger)

Testflinger is a way to deploy on a remote bare-metal server without manual setup.

```bash
./local-testflinger.sh lp:username   # or gh:username
```

Packages the repo as `repository.tar.gz`, submits a Testflinger job that provisions a bare-metal host, copies the tarball, and runs `install_deps.sh` + `deploy.sh`.
