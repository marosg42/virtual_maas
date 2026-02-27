include "stack" {
  path   = find_in_parent_folders("stack.hcl")
  expose = true
}

terraform {
  source = "./"
}

dependency "maas" {
  config_path = "../maas"

  mock_outputs = {
    maas_api_key               = "ConsumerSecret:TokenKey:TokenSecret"
    maas_controller_ip_address = "1.2.3.4"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

inputs = merge(
  include.stack.locals.stack_config,
  {
    maas_api_key               = dependency.maas.outputs.maas_api_key
    maas_controller_ip_address = dependency.maas.outputs.maas_controller_ip_address
  }
)
