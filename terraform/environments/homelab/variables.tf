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
  description = "Proxmox node that will host the Phase 1 scaffold guests."
  type        = string

  validation {
    condition     = length(trimspace(var.target_node_name)) > 0
    error_message = "target_node_name must not be empty."
  }
}

variable "vm_name" {
  description = "Example VM name for the first larger stack guest."
  type        = string
  default     = "monitoring-01"
}

variable "vm_clone_source_vm_id" {
  description = "Template or source VM ID used to clone the example VM."
  type        = number

  validation {
    condition     = var.vm_clone_source_vm_id > 0
    error_message = "vm_clone_source_vm_id must be greater than 0."
  }
}

variable "vm_datastore_id" {
  description = "Datastore for the example VM disk."
  type        = string

  validation {
    condition     = length(trimspace(var.vm_datastore_id)) > 0
    error_message = "vm_datastore_id must not be empty."
  }
}

variable "vm_bridge" {
  description = "Bridge for the example VM network interface."
  type        = string

  validation {
    condition     = length(trimspace(var.vm_bridge)) > 0
    error_message = "vm_bridge must not be empty."
  }
}

variable "vm_cpu_cores" {
  description = "Baseline CPU cores for the example VM."
  type        = number
  default     = 2

  validation {
    condition     = var.vm_cpu_cores >= 1
    error_message = "vm_cpu_cores must be at least 1."
  }
}

variable "vm_memory_mb" {
  description = "Baseline memory in MiB for the example VM."
  type        = number
  default     = 4096

  validation {
    condition     = var.vm_memory_mb >= 512
    error_message = "vm_memory_mb must be at least 512."
  }
}

variable "vm_disk_size_gb" {
  description = "Baseline disk size in GiB for the example VM."
  type        = number
  default     = 32

  validation {
    condition     = var.vm_disk_size_gb >= 1
    error_message = "vm_disk_size_gb must be at least 1."
  }
}

variable "vm_full_clone" {
  description = "Whether the example VM should use a full clone."
  type        = bool
  default     = true
}

variable "vm_network_model" {
  description = "Network model for the example VM interface."
  type        = string
  default     = "virtio"
}

variable "vm_vlan_tag" {
  description = "Optional VLAN tag for the example VM interface."
  type        = number
  default     = null
  nullable    = true
}

variable "lxc_vm_id" {
  description = "Explicit VMID for the example LXC guest."
  type        = number

  validation {
    condition     = var.lxc_vm_id > 0
    error_message = "lxc_vm_id must be greater than 0."
  }
}

variable "lxc_hostname" {
  description = "Example hostname for the first lightweight service guest."
  type        = string
  default     = "utility-01"

  validation {
    condition     = length(trimspace(var.lxc_hostname)) > 0
    error_message = "lxc_hostname must not be empty."
  }
}

variable "lxc_template_file_id" {
  description = "Template file ID for the example LXC image."
  type        = string

  validation {
    condition     = length(trimspace(var.lxc_template_file_id)) > 0
    error_message = "lxc_template_file_id must not be empty."
  }
}

variable "lxc_datastore_id" {
  description = "Datastore for the example LXC disk."
  type        = string

  validation {
    condition     = length(trimspace(var.lxc_datastore_id)) > 0
    error_message = "lxc_datastore_id must not be empty."
  }
}

variable "lxc_bridge" {
  description = "Bridge for the example LXC network interface."
  type        = string

  validation {
    condition     = length(trimspace(var.lxc_bridge)) > 0
    error_message = "lxc_bridge must not be empty."
  }
}

variable "lxc_cpu_cores" {
  description = "Baseline CPU cores for the example LXC."
  type        = number
  default     = 1

  validation {
    condition     = var.lxc_cpu_cores >= 1
    error_message = "lxc_cpu_cores must be at least 1."
  }
}

variable "lxc_memory_mb" {
  description = "Baseline memory in MiB for the example LXC."
  type        = number
  default     = 512

  validation {
    condition     = var.lxc_memory_mb >= 128
    error_message = "lxc_memory_mb must be at least 128."
  }
}

variable "lxc_swap_mb" {
  description = "Baseline swap in MiB for the example LXC."
  type        = number
  default     = 512

  validation {
    condition     = var.lxc_swap_mb >= 0
    error_message = "lxc_swap_mb cannot be negative."
  }
}

variable "lxc_disk_size_gb" {
  description = "Baseline disk size in GiB for the example LXC."
  type        = number
  default     = 8

  validation {
    condition     = var.lxc_disk_size_gb >= 1
    error_message = "lxc_disk_size_gb must be at least 1."
  }
}

variable "lxc_network_interface_name" {
  description = "Primary interface name for the example LXC."
  type        = string
  default     = "eth0"
}

variable "lxc_ipv4_address" {
  description = "IPv4 address for the example LXC, or dhcp for automatic assignment."
  type        = string
  default     = "dhcp"
}

variable "lxc_started" {
  description = "Whether the example LXC should start after creation."
  type        = bool
  default     = true
}

variable "lxc_start_on_boot" {
  description = "Whether the example LXC should start on node boot."
  type        = bool
  default     = true
}

variable "lxc_unprivileged" {
  description = "Whether the example LXC should be unprivileged."
  type        = bool
  default     = true
}

variable "lxc_description" {
  description = "Optional description for the example LXC."
  type        = string
  default     = "Phase 1 scaffold example container"
}

variable "lxc_tags" {
  description = "Optional lowercase tags for the example LXC to avoid Proxmox diff noise."
  type        = list(string)
  default     = ["phase-1", "scaffold"]
}

variable "lxc_os_type" {
  description = "Container operating system type for the example LXC."
  type        = string
  default     = "unmanaged"
}
