variable "proxmox_endpoint" {
  description = "Proxmox API endpoint for this homelab environment. Export the API token separately with PROXMOX_VE_API_TOKEN."
  type        = string

  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "proxmox_endpoint must start with https://."
  }
}

variable "proxmox_insecure" {
  description = "Set true only when the homelab uses a self-signed Proxmox certificate."
  type        = bool
  default     = true
}

variable "target_node_name" {
  description = "Proxmox node that hosts the guests in this environment."
  type        = string

  validation {
    condition     = length(trimspace(var.target_node_name)) > 0
    error_message = "target_node_name must not be empty."
  }
}

variable "vms" {
  description = "Configuration for VM-based workloads keyed by service name."
  type = map(object({
    guest_name              = string
    clone_source_vm_id      = number
    cpu_cores               = number
    memory_mb               = number
    disk_datastore_id       = string
    disk_size_gb            = number
    bridge                  = string
    full_clone              = optional(bool, true)
    network_model           = optional(string, "virtio")
    network_vlan_tag        = optional(number)
    cloud_init_datastore_id = optional(string, "local")
    user_name               = optional(string, "debian")
    ssh_public_keys         = optional(list(string), [])
    ipv4_address            = optional(string, "dhcp")
    ipv4_gateway            = optional(string)
  }))

  validation {
    condition = length(var.vms) > 0 && alltrue([
      for name, vm in var.vms :
      length(trimspace(name)) > 0 &&
      length(trimspace(vm.guest_name)) > 0 &&
      vm.clone_source_vm_id > 0 &&
      vm.cpu_cores >= 1 &&
      vm.memory_mb >= 512 &&
      vm.disk_size_gb >= 1 &&
      length(trimspace(vm.disk_datastore_id)) > 0 &&
      length(trimspace(vm.bridge)) > 0 &&
      length(trimspace(vm.cloud_init_datastore_id)) > 0 &&
      length(trimspace(vm.user_name)) > 0
    ])
    error_message = "Each VM must define a non-empty name, clone source, valid sizing, and non-empty datastore, bridge, cloud-init datastore, and user values."
  }

  validation {
    condition = alltrue([
      for _, vm in var.vms :
      (vm.ipv4_address == "dhcp" || can(regex(".+/.+", vm.ipv4_address))) &&
      (vm.ipv4_address == "dhcp" ? vm.ipv4_gateway == null : length(trimspace(coalesce(vm.ipv4_gateway, ""))) > 0)
    ])
    error_message = "Each VM ipv4_address must be dhcp or CIDR-formatted, and ipv4_gateway must be set only for static addressing."
  }

  validation {
    condition = alltrue(flatten([
      for _, vm in var.vms : [
        alltrue([for key in vm.ssh_public_keys : length(trimspace(key)) > 0])
      ]
    ]))
    error_message = "VM ssh_public_keys entries must not be empty."
  }
}

variable "lxcs" {
  description = "Configuration for LXC-based services keyed by service name."
  type = map(object({
    vm_id                  = number
    hostname               = string
    template_file_id       = string
    disk_datastore_id      = string
    bridge                 = string
    dns_servers            = list(string)
    ssh_public_keys        = optional(list(string), [])
    cpu_cores              = optional(number, 1)
    memory_mb              = optional(number, 512)
    swap_mb                = optional(number, 0)
    disk_size_gb           = optional(number, 4)
    network_interface_name = optional(string, "eth0")
    ipv4_address           = optional(string, "dhcp")
    ipv4_gateway           = optional(string)
    started                = optional(bool, true)
    start_on_boot          = optional(bool, true)
    unprivileged           = optional(bool, true)
    description            = optional(string)
    tags                   = optional(list(string), [])
    os_type                = string
  }))

  validation {
    condition = length(var.lxcs) > 0 && alltrue([
      for name, lxc in var.lxcs :
      length(trimspace(name)) > 0 &&
      lxc.vm_id > 0 &&
      length(trimspace(lxc.hostname)) > 0 &&
      length(trimspace(lxc.template_file_id)) > 0 &&
      length(trimspace(lxc.disk_datastore_id)) > 0 &&
      length(trimspace(lxc.bridge)) > 0 &&
      length(trimspace(lxc.os_type)) > 0 &&
      lxc.cpu_cores >= 1 &&
      lxc.memory_mb >= 128 &&
      lxc.swap_mb >= 0 &&
      lxc.disk_size_gb >= 1
    ])
    error_message = "Each LXC must define a non-empty name, hostname, template, datastore, bridge, os_type, and valid sizing values."
  }

  validation {
    condition = alltrue([
      for _, lxc in var.lxcs :
      (lxc.ipv4_address == "dhcp" || can(regex(".+/.+", lxc.ipv4_address))) &&
      (lxc.ipv4_address == "dhcp" ? lxc.ipv4_gateway == null : length(trimspace(coalesce(lxc.ipv4_gateway, ""))) > 0)
    ])
    error_message = "Each LXC ipv4_address must be dhcp or CIDR-formatted, and ipv4_gateway must be set only for static addressing."
  }

  validation {
    condition = alltrue(flatten([
      for _, lxc in var.lxcs : [
        length(lxc.dns_servers) > 0,
        alltrue([for server in lxc.dns_servers : length(trimspace(server)) > 0]),
        alltrue([for key in lxc.ssh_public_keys : length(trimspace(key)) > 0])
      ]
    ]))
    error_message = "Each LXC must provide at least one non-empty DNS server, and ssh_public_keys entries must not be empty."
  }
}
