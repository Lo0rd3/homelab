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

variable "vm_cloud_init_datastore_id" {
  description = "Datastore used for the example VM cloud-init drive."
  type        = string
  default     = "local"

  validation {
    condition     = length(trimspace(var.vm_cloud_init_datastore_id)) > 0
    error_message = "vm_cloud_init_datastore_id must not be empty."
  }
}

variable "vm_user" {
  description = "Cloud-init username for the example VM."
  type        = string
  default     = "debian"

  validation {
    condition     = length(trimspace(var.vm_user)) > 0
    error_message = "vm_user must not be empty."
  }
}

variable "vm_ssh_public_keys" {
  description = "SSH public keys for the example VM user."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.vm_ssh_public_keys : length(trimspace(key)) > 0])
    error_message = "vm_ssh_public_keys entries must not be empty."
  }
}

variable "vm_ipv4_address" {
  description = "Cloud-init IPv4 address for the example VM, or dhcp."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.vm_ipv4_address == "dhcp" || can(regex(".+/.+", var.vm_ipv4_address))
    error_message = "vm_ipv4_address must be dhcp or a CIDR-style IPv4 address like 192.168.1.50/24."
  }
}

variable "vm_ipv4_gateway" {
  description = "Optional IPv4 gateway for the example VM when using a static address."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.vm_ipv4_address == "dhcp" ? var.vm_ipv4_gateway == null : true
    error_message = "vm_ipv4_gateway must be null when vm_ipv4_address is dhcp."
  }
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
  description = "Hostname for the Tailscale router LXC."
  type        = string
  default     = "tailscale-01"

  validation {
    condition     = length(trimspace(var.lxc_hostname)) > 0
    error_message = "lxc_hostname must not be empty."
  }
}

variable "lxc_template_file_id" {
  description = "Template file ID for the Tailscale router Debian LXC image."
  type        = string

  validation {
    condition     = length(trimspace(var.lxc_template_file_id)) > 0
    error_message = "lxc_template_file_id must not be empty."
  }
}

variable "lxc_datastore_id" {
  description = "Datastore for the Tailscale router LXC disk."
  type        = string

  validation {
    condition     = length(trimspace(var.lxc_datastore_id)) > 0
    error_message = "lxc_datastore_id must not be empty."
  }
}

variable "lxc_bridge" {
  description = "Bridge for the Tailscale router LXC network interface."
  type        = string

  validation {
    condition     = length(trimspace(var.lxc_bridge)) > 0
    error_message = "lxc_bridge must not be empty."
  }
}

variable "lxc_cpu_cores" {
  description = "CPU cores for the Tailscale router LXC."
  type        = number
  default     = 1

  validation {
    condition     = var.lxc_cpu_cores >= 1
    error_message = "lxc_cpu_cores must be at least 1."
  }
}

variable "lxc_memory_mb" {
  description = "Memory in MiB for the Tailscale router LXC."
  type        = number
  default     = 1024

  validation {
    condition     = var.lxc_memory_mb >= 128
    error_message = "lxc_memory_mb must be at least 128."
  }
}

variable "lxc_swap_mb" {
  description = "Swap in MiB for the Tailscale router LXC."
  type        = number
  default     = 256

  validation {
    condition     = var.lxc_swap_mb >= 0
    error_message = "lxc_swap_mb cannot be negative."
  }
}

variable "lxc_disk_size_gb" {
  description = "Disk size in GiB for the Tailscale router LXC."
  type        = number
  default     = 6

  validation {
    condition     = var.lxc_disk_size_gb >= 1
    error_message = "lxc_disk_size_gb must be at least 1."
  }
}

variable "lxc_network_interface_name" {
  description = "Primary interface name for the Tailscale router LXC."
  type        = string
  default     = "eth0"
}

variable "lxc_ipv4_address" {
  description = "IPv4 address for the Tailscale router LXC, or dhcp for automatic assignment."
  type        = string
  default     = "192.168.1.2/24"

  validation {
    condition     = var.lxc_ipv4_address == "dhcp" || can(regex(".+/.+", var.lxc_ipv4_address))
    error_message = "lxc_ipv4_address must be dhcp or a CIDR-style IPv4 address like 192.168.1.2/24."
  }
}

variable "lxc_ipv4_gateway" {
  description = "IPv4 gateway for the Tailscale router LXC when using a static address."
  type        = string
  default     = "192.168.1.254"

  validation {
    condition     = var.lxc_ipv4_address == "dhcp" ? var.lxc_ipv4_gateway == null : length(trimspace(var.lxc_ipv4_gateway)) > 0
    error_message = "lxc_ipv4_gateway must be set when lxc_ipv4_address is static."
  }
}

variable "lxc_dns_servers" {
  description = "DNS servers for the Tailscale router LXC."
  type        = list(string)
  default     = ["192.168.1.252"]

  validation {
    condition     = length(var.lxc_dns_servers) > 0 && alltrue([for server in var.lxc_dns_servers : length(trimspace(server)) > 0])
    error_message = "lxc_dns_servers must contain at least one non-empty DNS server address."
  }
}

variable "lxc_ssh_public_keys" {
  description = "SSH public keys injected into the Tailscale router LXC for management access."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.lxc_ssh_public_keys : length(trimspace(key)) > 0])
    error_message = "lxc_ssh_public_keys entries must not be empty."
  }
}

variable "lxc_started" {
  description = "Whether the Tailscale router LXC should start after creation."
  type        = bool
  default     = true
}

variable "lxc_start_on_boot" {
  description = "Whether the Tailscale router LXC should start on node boot."
  type        = bool
  default     = true
}

variable "lxc_unprivileged" {
  description = "Whether the Tailscale router LXC should be unprivileged."
  type        = bool
  default     = true
}

variable "lxc_description" {
  description = "Optional description for the Tailscale router LXC."
  type        = string
  default     = "Tailscale subnet router and exit node"
}

variable "lxc_tags" {
  description = "Optional lowercase tags for the Tailscale router LXC to avoid Proxmox diff noise."
  type        = list(string)
  default     = ["tailscale", "router", "remote-access"]
}

variable "lxc_os_type" {
  description = "Container operating system type for the Tailscale router LXC."
  type        = string
  default     = "unmanaged"
}

variable "adguard_lxc_vm_id" {
  description = "Explicit VMID for the AdGuard migration LXC guest."
  type        = number
  default     = 202

  validation {
    condition     = var.adguard_lxc_vm_id > 0
    error_message = "adguard_lxc_vm_id must be greater than 0."
  }
}

variable "adguard_lxc_hostname" {
  description = "Hostname for the AdGuard migration LXC."
  type        = string
  default     = "adguard-01"

  validation {
    condition     = length(trimspace(var.adguard_lxc_hostname)) > 0
    error_message = "adguard_lxc_hostname must not be empty."
  }
}

variable "adguard_lxc_template_file_id" {
  description = "Template file ID for the AdGuard Alpine LXC image."
  type        = string
  default     = "local:vztmpl/alpine-3.23-default_20260116_amd64.tar.xz"

  validation {
    condition     = length(trimspace(var.adguard_lxc_template_file_id)) > 0
    error_message = "adguard_lxc_template_file_id must not be empty."
  }
}

variable "adguard_lxc_datastore_id" {
  description = "Datastore for the AdGuard LXC disk."
  type        = string
  default     = "local"

  validation {
    condition     = length(trimspace(var.adguard_lxc_datastore_id)) > 0
    error_message = "adguard_lxc_datastore_id must not be empty."
  }
}

variable "adguard_lxc_bridge" {
  description = "Bridge for the AdGuard LXC network interface."
  type        = string
  default     = "vmbr0"

  validation {
    condition     = length(trimspace(var.adguard_lxc_bridge)) > 0
    error_message = "adguard_lxc_bridge must not be empty."
  }
}

variable "adguard_lxc_cpu_cores" {
  description = "CPU cores for the AdGuard LXC."
  type        = number
  default     = 1

  validation {
    condition     = var.adguard_lxc_cpu_cores >= 1
    error_message = "adguard_lxc_cpu_cores must be at least 1."
  }
}

variable "adguard_lxc_memory_mb" {
  description = "Memory in MiB for the AdGuard LXC."
  type        = number
  default     = 512

  validation {
    condition     = var.adguard_lxc_memory_mb >= 128
    error_message = "adguard_lxc_memory_mb must be at least 128."
  }
}

variable "adguard_lxc_swap_mb" {
  description = "Swap in MiB for the AdGuard LXC."
  type        = number
  default     = 512

  validation {
    condition     = var.adguard_lxc_swap_mb >= 0
    error_message = "adguard_lxc_swap_mb cannot be negative."
  }
}

variable "adguard_lxc_disk_size_gb" {
  description = "Disk size in GiB for the AdGuard LXC."
  type        = number
  default     = 6

  validation {
    condition     = var.adguard_lxc_disk_size_gb >= 1
    error_message = "adguard_lxc_disk_size_gb must be at least 1."
  }
}

variable "adguard_lxc_network_interface_name" {
  description = "Primary interface name for the AdGuard LXC."
  type        = string
  default     = "eth0"
}

variable "adguard_lxc_ipv4_address" {
  description = "IPv4 address for the AdGuard LXC."
  type        = string
  default     = "192.168.1.252/24"

  validation {
    condition     = can(regex(".+/.+", var.adguard_lxc_ipv4_address))
    error_message = "adguard_lxc_ipv4_address must be a CIDR-style IPv4 address like 192.168.1.252/24."
  }
}

variable "adguard_lxc_ipv4_gateway" {
  description = "IPv4 gateway for the AdGuard LXC."
  type        = string
  default     = "192.168.1.254"

  validation {
    condition     = length(trimspace(var.adguard_lxc_ipv4_gateway)) > 0
    error_message = "adguard_lxc_ipv4_gateway must not be empty."
  }
}

variable "adguard_lxc_dns_servers" {
  description = "DNS servers for the AdGuard LXC."
  type        = list(string)
  default     = ["212.55.154.174"]

  validation {
    condition     = length(var.adguard_lxc_dns_servers) > 0 && alltrue([for server in var.adguard_lxc_dns_servers : length(trimspace(server)) > 0])
    error_message = "adguard_lxc_dns_servers must contain at least one non-empty DNS server address."
  }
}

variable "adguard_lxc_ssh_public_keys" {
  description = "SSH public keys injected into the AdGuard LXC for management access."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.adguard_lxc_ssh_public_keys : length(trimspace(key)) > 0])
    error_message = "adguard_lxc_ssh_public_keys entries must not be empty."
  }
}

variable "adguard_lxc_started" {
  description = "Whether the AdGuard LXC should start after creation."
  type        = bool
  default     = true
}

variable "adguard_lxc_start_on_boot" {
  description = "Whether the AdGuard LXC should start on node boot."
  type        = bool
  default     = true
}

variable "adguard_lxc_unprivileged" {
  description = "Whether the AdGuard LXC should be unprivileged."
  type        = bool
  default     = true
}

variable "adguard_lxc_description" {
  description = "Optional description for the AdGuard LXC."
  type        = string
  default     = "AdGuard Home migration LXC"
}

variable "adguard_lxc_tags" {
  description = "Optional lowercase tags for the AdGuard LXC."
  type        = list(string)
  default     = ["adguard", "dns", "dhcp"]
}

variable "adguard_lxc_os_type" {
  description = "Container operating system type for the AdGuard LXC."
  type        = string
  default     = "alpine"
}
