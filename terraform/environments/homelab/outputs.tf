output "vm_id" {
  description = "Terraform identifier for the example VM scaffold."
  value       = module.vm.id
}

output "vm_name" {
  description = "Guest name used by the example VM scaffold."
  value       = module.vm.guest_name
}

output "lxc_id" {
  description = "Terraform identifier for the example LXC scaffold."
  value       = module.lxc.id
}

output "lxc_vmid" {
  description = "Assigned VMID for the example LXC scaffold."
  value       = module.lxc.vm_id
}

output "lxc_ipv4" {
  description = "IPv4 data reported by Proxmox for the example LXC scaffold."
  value       = module.lxc.ipv4
}

output "lxc_hostname" {
  description = "Hostname used by the current homelab LXC service guest."
  value       = var.lxc_hostname
}
