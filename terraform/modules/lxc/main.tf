terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.78.0"
    }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  node_name = var.node_name
  vm_id     = var.vm_id

  started       = var.started
  start_on_boot = var.start_on_boot
  unprivileged  = var.unprivileged
  description   = var.description
  tags          = var.tags

  cpu {
    cores = var.cpu_cores
    units = var.cpu_units
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.disk_datastore_id
    size         = var.disk_size_gb
  }

  network_interface {
    name   = var.network_interface_name
    bridge = var.bridge
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ipv4_address
      }
    }
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }
}
