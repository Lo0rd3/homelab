output "vms" {
  description = "Summary of the VM workloads managed by this environment."
  value = {
    for name, instance in module.vms : name => {
      id         = instance.id
      guest_name = instance.guest_name
      node_name  = instance.node_name
    }
  }
}

output "lxcs" {
  description = "Summary of the LXC services managed by this environment."
  value = {
    for name, instance in module.lxcs : name => {
      id        = instance.id
      vm_id     = instance.vm_id
      node_name = instance.node_name
      hostname  = var.lxcs[name].hostname
      ipv4      = instance.ipv4
    }
  }
}
