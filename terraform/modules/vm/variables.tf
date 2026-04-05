variable "node_name" {
  description = "Proxmox node that will host the VM."
  type        = string

  validation {
    condition     = length(trimspace(var.node_name)) > 0
    error_message = "node_name must not be empty."
  }
}

variable "guest_name" {
  description = "Guest name for the VM, such as monitoring-01."
  type        = string

  validation {
    condition     = length(trimspace(var.guest_name)) > 0
    error_message = "guest_name must not be empty."
  }
}

variable "clone_source_vm_id" {
  description = "Template or source VM ID used for cloning."
  type        = number

  validation {
    condition     = var.clone_source_vm_id > 0
    error_message = "clone_source_vm_id must be greater than 0."
  }
}

variable "cpu_cores" {
  description = "Number of vCPU cores assigned to the VM."
  type        = number

  validation {
    condition     = var.cpu_cores >= 1
    error_message = "cpu_cores must be at least 1."
  }
}

variable "memory_mb" {
  description = "Memory assigned to the VM in MiB."
  type        = number

  validation {
    condition     = var.memory_mb >= 512
    error_message = "memory_mb must be at least 512."
  }
}

variable "disk_datastore_id" {
  description = "Proxmox datastore ID for the primary VM disk."
  type        = string

  validation {
    condition     = length(trimspace(var.disk_datastore_id)) > 0
    error_message = "disk_datastore_id must not be empty."
  }
}

variable "disk_size_gb" {
  description = "Primary VM disk size in GiB."
  type        = number

  validation {
    condition     = var.disk_size_gb >= 1
    error_message = "disk_size_gb must be at least 1."
  }
}

variable "bridge" {
  description = "Bridge used by the primary network interface."
  type        = string

  validation {
    condition     = length(trimspace(var.bridge)) > 0
    error_message = "bridge must not be empty."
  }
}

variable "full_clone" {
  description = "Whether to perform a full clone from the source template."
  type        = bool
  default     = true
}

variable "network_model" {
  description = "Virtual NIC model for the primary interface."
  type        = string
  default     = "virtio"
}

variable "network_vlan_tag" {
  description = "Optional VLAN tag for the primary interface."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.network_vlan_tag == null || var.network_vlan_tag >= 1
    error_message = "network_vlan_tag must be null or greater than 0."
  }
}

variable "cloud_init_datastore_id" {
  description = "Datastore used for the VM cloud-init drive."
  type        = string

  validation {
    condition     = length(trimspace(var.cloud_init_datastore_id)) > 0
    error_message = "cloud_init_datastore_id must not be empty."
  }
}

variable "user_name" {
  description = "Username configured through cloud-init for the cloned VM."
  type        = string
  default     = "debian"

  validation {
    condition     = length(trimspace(var.user_name)) > 0
    error_message = "user_name must not be empty."
  }
}

variable "ssh_public_keys" {
  description = "SSH public keys configured through cloud-init for the cloned VM user."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.ssh_public_keys : length(trimspace(key)) > 0])
    error_message = "ssh_public_keys entries must not be empty."
  }
}

variable "ipv4_address" {
  description = "IPv4 address in cloud-init format, or dhcp for automatic assignment."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.ipv4_address == "dhcp" || can(regex(".+/.+", var.ipv4_address))
    error_message = "ipv4_address must be dhcp or a CIDR-style IPv4 address like 192.168.1.50/24."
  }
}

variable "ipv4_gateway" {
  description = "Optional IPv4 gateway for static addressing. Leave null when using dhcp."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.ipv4_address == "dhcp" ? var.ipv4_gateway == null : true
    error_message = "ipv4_gateway must be null when ipv4_address is dhcp."
  }
}
