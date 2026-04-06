variable "node_name" {
  description = "Proxmox node that will host the container."
  type        = string
}

variable "vm_id" {
  description = "Numeric VMID for the container."
  type        = number

  validation {
    condition     = var.vm_id > 0
    error_message = "vm_id must be greater than 0."
  }
}

variable "hostname" {
  description = "Container hostname."
  type        = string
}

variable "template_file_id" {
  description = "Template file identifier used by Proxmox for the container OS image."
  type        = string
}

variable "cpu_cores" {
  description = "Number of CPU cores assigned to the container."
  type        = number
  default     = 1

  validation {
    condition     = var.cpu_cores >= 1
    error_message = "cpu_cores must be at least 1."
  }
}

variable "cpu_units" {
  description = "CPU weight for the container."
  type        = number
  default     = 1024

  validation {
    condition     = var.cpu_units >= 1
    error_message = "cpu_units must be at least 1."
  }
}

variable "memory_mb" {
  description = "Dedicated memory in MiB."
  type        = number
  default     = 512

  validation {
    condition     = var.memory_mb >= 128
    error_message = "memory_mb must be at least 128 MiB."
  }
}

variable "swap_mb" {
  description = "Swap memory in MiB."
  type        = number
  default     = 0

  validation {
    condition     = var.swap_mb >= 0
    error_message = "swap_mb cannot be negative."
  }
}

variable "disk_datastore_id" {
  description = "Datastore that will hold the container disk."
  type        = string
}

variable "disk_size_gb" {
  description = "Container disk size in GiB."
  type        = number
  default     = 4

  validation {
    condition     = var.disk_size_gb >= 1
    error_message = "disk_size_gb must be at least 1 GiB."
  }
}

variable "bridge" {
  description = "Bridge used by the primary network interface."
  type        = string
}

variable "network_interface_name" {
  description = "Name of the primary container network interface."
  type        = string
  default     = "eth0"
}

variable "ipv4_address" {
  description = "IPv4 address for the container, or dhcp for automatic assignment."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.ipv4_address == "dhcp" || can(regex(".+/.+", var.ipv4_address))
    error_message = "ipv4_address must be dhcp or a CIDR-style IPv4 address like 192.168.1.2/24."
  }
}

variable "ipv4_gateway" {
  description = "Optional IPv4 gateway for the container. Leave null when using dhcp."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.ipv4_address == "dhcp" ? var.ipv4_gateway == null : length(trimspace(coalesce(var.ipv4_gateway, ""))) > 0
    error_message = "ipv4_gateway must be set when using a static ipv4_address, and null when using dhcp."
  }
}

variable "dns_servers" {
  description = "DNS servers configured inside the container."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.dns_servers) > 0 && alltrue([for server in var.dns_servers : length(trimspace(server)) > 0])
    error_message = "dns_servers must contain at least one non-empty DNS server address."
  }
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into the container user account for management access."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.ssh_public_keys : length(trimspace(key)) > 0])
    error_message = "ssh_public_keys entries must not be empty."
  }
}

variable "started" {
  description = "Whether the container should be started after creation."
  type        = bool
  default     = true
}

variable "start_on_boot" {
  description = "Whether the container should start automatically on node boot."
  type        = bool
  default     = true
}

variable "unprivileged" {
  description = "Whether to create the container as unprivileged."
  type        = bool
  default     = true
}

variable "description" {
  description = "Optional Proxmox description for the container."
  type        = string
  default     = null
}

variable "tags" {
  description = "Optional tags for the container. Use lowercase to avoid diff noise."
  type        = list(string)
  default     = []
}

variable "os_type" {
  description = "Container operating system type."
  type        = string
  default     = "unmanaged"
}
