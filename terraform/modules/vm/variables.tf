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
