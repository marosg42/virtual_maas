variable "juju_channel" {
  description = "Juju snap channel (e.g. 3/stable, 4.0/candidate)"
  type        = string
  default     = "4.0/stable"
}

variable "maas_api_key" {
  description = "MAAS Admin API Key"
  type        = string
  sensitive   = true
}

variable "maas_controller_ip_address" {
  description = "MAAS Controller IP Address"
  type        = string
}

variable "juju_nodes_count" {
  description = "Number of Juju nodes (0, 1, or 3)"
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 3], var.juju_nodes_count)
    error_message = "juju_nodes_count must be one of 0, 1, or 3."
  }
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key"
  type        = string
  default     = "~/.ssh/passwordless"
}
