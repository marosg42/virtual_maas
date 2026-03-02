locals {
  units = {
    bridge = {
      source = "./bridge"
    }

    virtualnodes = {
      source = "./virtualnodes"
      dependencies = ["bridge"]
    }

    maas = {
      source = "./maas"
      dependencies = ["virtualnodes"]
    }

    juju_controller = {
      source       = "./juju_controller"
      dependencies = ["maas"]
    }
  }

  # Stack-wide variables
  stack_config = {
    ssh_private_key_path = "~/.ssh/passwordless"
    ssh_public_key_path  = "~/.ssh/passwordless.pub"
    libvirt_uri          = get_env("LIBVIRT_DEFAULT_URI", "qemu:///system")
    maas_hostname        = "maas-controller"

    node_mem             = "8192"      # 8 GB per node
    node_vcpu            = 4           # 4 vCPUs per node
    maas_controller_mem  = "8192"      # 8 GB for MAAS controller
    maas_controller_vcpu = 4

    juju_channel         = "4.0/stable" # Juju snap channel (e.g. 3/stable, 4.0/candidate)

    # Juju nodes configuration
    juju_nodes_count     = 3           # Number of Juju nodes (0, 1, or 3)
    juju_node_mem        = "4096"      # 4 GB per Juju node
    juju_node_vcpu       = 2           # 2 vCPUs per Juju node

  }
}
