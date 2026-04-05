module "vm" {
  source = "../../modules/vm"

  node_name               = var.target_node_name
  guest_name              = var.vm_name
  clone_source_vm_id      = var.vm_clone_source_vm_id
  cpu_cores               = var.vm_cpu_cores
  memory_mb               = var.vm_memory_mb
  disk_datastore_id       = var.vm_datastore_id
  disk_size_gb            = var.vm_disk_size_gb
  bridge                  = var.vm_bridge
  full_clone              = var.vm_full_clone
  network_model           = var.vm_network_model
  network_vlan_tag        = var.vm_vlan_tag
  cloud_init_datastore_id = var.vm_cloud_init_datastore_id
  user_name               = var.vm_user
  ssh_public_keys         = var.vm_ssh_public_keys
  ipv4_address            = var.vm_ipv4_address
  ipv4_gateway            = var.vm_ipv4_gateway
}

module "lxc" {
  source = "../../modules/lxc"

  node_name              = var.target_node_name
  vm_id                  = var.lxc_vm_id
  hostname               = var.lxc_hostname
  template_file_id       = var.lxc_template_file_id
  cpu_cores              = var.lxc_cpu_cores
  memory_mb              = var.lxc_memory_mb
  swap_mb                = var.lxc_swap_mb
  disk_datastore_id      = var.lxc_datastore_id
  disk_size_gb           = var.lxc_disk_size_gb
  bridge                 = var.lxc_bridge
  network_interface_name = var.lxc_network_interface_name
  ipv4_address           = var.lxc_ipv4_address
  started                = var.lxc_started
  start_on_boot          = var.lxc_start_on_boot
  unprivileged           = var.lxc_unprivileged
  description            = var.lxc_description
  tags                   = var.lxc_tags
  os_type                = var.lxc_os_type
}
