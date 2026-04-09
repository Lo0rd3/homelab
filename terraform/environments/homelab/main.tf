module "vms" {
  for_each = var.vms
  source   = "../../modules/vm"

  node_name               = var.target_node_name
  guest_name              = each.value.guest_name
  clone_source_vm_id      = each.value.clone_source_vm_id
  cpu_cores               = each.value.cpu_cores
  memory_mb               = each.value.memory_mb
  disk_datastore_id       = each.value.disk_datastore_id
  disk_size_gb            = each.value.disk_size_gb
  bridge                  = each.value.bridge
  full_clone              = each.value.full_clone
  network_model           = each.value.network_model
  network_vlan_tag        = each.value.network_vlan_tag
  cloud_init_datastore_id = each.value.cloud_init_datastore_id
  user_name               = each.value.user_name
  ssh_public_keys         = each.value.ssh_public_keys
  ipv4_address            = each.value.ipv4_address
  ipv4_gateway            = each.value.ipv4_gateway
}

module "lxcs" {
  for_each = var.lxcs
  source   = "../../modules/lxc"

  node_name              = var.target_node_name
  vm_id                  = each.value.vm_id
  hostname               = each.value.hostname
  template_file_id       = each.value.template_file_id
  cpu_cores              = each.value.cpu_cores
  memory_mb              = each.value.memory_mb
  swap_mb                = each.value.swap_mb
  disk_datastore_id      = each.value.disk_datastore_id
  disk_size_gb           = each.value.disk_size_gb
  bridge                 = each.value.bridge
  network_interface_name = each.value.network_interface_name
  ipv4_address           = each.value.ipv4_address
  ipv4_gateway           = each.value.ipv4_gateway
  dns_servers            = each.value.dns_servers
  ssh_public_keys        = each.value.ssh_public_keys
  started                = each.value.started
  start_on_boot          = each.value.start_on_boot
  unprivileged           = each.value.unprivileged
  description            = each.value.description
  tags                   = each.value.tags
  os_type                = each.value.os_type
}
