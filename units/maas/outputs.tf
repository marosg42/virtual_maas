output "maas_api_key" {
  description = "MAAS Admin API Key"
  value       = var.maas_api_key
  sensitive   = true
}

output "maas_controller_ip_address" {
  description = "MAAS Controller IP Address"
  value       = var.maas_controller_ip_address
}
