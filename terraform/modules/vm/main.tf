terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_cloned_vm" "this" {
  node_name = var.node_name
  name      = var.guest_name
  clone = {
    source_vm_id = var.clone_source_vm_id
    full         = var.full_clone
  }

  cpu = {
    cores = var.cpu_cores
  }

  memory = {
    size = var.memory_mb
  }

  network = {
    net0 = {
      bridge = var.bridge
      model  = var.network_model
      tag    = var.network_vlan_tag
    }
  }

  disk = {
    scsi0 = {
      datastore_id = var.disk_datastore_id
      size_gb      = var.disk_size_gb
    }
  }
}
