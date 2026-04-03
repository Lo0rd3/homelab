output "id" {
  description = "Terraform resource identifier for the container."
  value       = proxmox_virtual_environment_container.this.id
}

output "vm_id" {
  description = "Assigned Proxmox VMID for the container."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "node_name" {
  description = "Proxmox node hosting the container."
  value       = proxmox_virtual_environment_container.this.node_name
}

output "ipv4" {
  description = "IPv4 data reported by Proxmox for the container."
  value       = proxmox_virtual_environment_container.this.ipv4
}

output "ipv6" {
  description = "IPv6 data reported by Proxmox for the container."
  value       = proxmox_virtual_environment_container.this.ipv6
}
