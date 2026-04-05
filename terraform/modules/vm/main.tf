terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  node_name  = var.node_name
  name       = var.guest_name
  boot_order = ["scsi0"]

  clone {
    vm_id        = var.clone_source_vm_id
    full         = var.full_clone
    datastore_id = var.disk_datastore_id
  }

  disk {
    interface    = "scsi0"
    size         = var.disk_size_gb
    datastore_id = var.disk_datastore_id
  }

  agent {
    enabled = true
  }
  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
  }

  initialization {
    datastore_id = var.cloud_init_datastore_id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      username = var.user_name
      keys     = var.ssh_public_keys
    }
  }

  network_device {
    bridge  = var.bridge
    model   = var.network_model
    vlan_id = var.network_vlan_tag
  }

  serial_device {
    device = "socket"
  }
}
