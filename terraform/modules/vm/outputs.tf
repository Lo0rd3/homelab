output "id" {
  description = "Terraform resource identifier for the VM."
  value       = proxmox_virtual_environment_vm.this.id
}

output "guest_name" {
  description = "Guest name assigned to the VM."
  value       = var.guest_name
}

output "node_name" {
  description = "Proxmox node hosting the VM."
  value       = var.node_name
}
