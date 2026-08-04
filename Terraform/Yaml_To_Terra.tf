terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.0" 
    }
  }
}

locals {
# Lees het YAML-bestand in en converteer het naar een Terraform-lijst
  yaml_data = yamldecode(file("${path.module}/infrastructure.yaml"))
  # Maak een map van de nodes zodat we for_each kunnen gebruiken
  nodes     = { for node in local.yaml_data.infrastructure.nodes : node.name => node }
}
provider "proxmox" {
  endpoint  = "https://192.168.1.35:8006/"
  api_token = "terraform@pve!provider8a6722e8-1119-4b87-97b2-65c79d6b5ab1"
  insecure  = true # Zet op false als je geldige SSL-certificaten gebruikt
}

resource "proxmox_virtual_environment_vm" "dynamic_vms" {
  for_each = local.nodes

  name        = each.value.name
  description = "Beheerd via Terraform - ${local.yaml_data.infrastructure.name} v${local.yaml_data.infrastructure.version}"
  node_name   = "pve"
  vm_id       = each.value.vm_id

  clone {
    vm_id = each.value.template_id
  }

  cpu {
    cores = tonumber(each.value.specs.cpu)
  }

  memory {
    dedicated = tonumber(each.value.specs.ram)
  }

  network_device {
    bridge = each.value.network.bridge
  }

  # DYNAMISCHE DISKS: Dit blok herhaalt zich voor elke disk in de YAML
  dynamic "disk" {
    for_each = each.value.disks
    content {
      size         = tonumber(disk.value.size)
      datastore_id = disk.value.storage
      interface    = "scsi${disk.key}" # Wordt automatisch scsi0, scsi1, etc.
    }
  }

  # GEAVANCEERDE CLOUD-INIT
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.network.ip_address}/24"
        gateway = "192.168.1.1"
      }
    }

    user_account {
      username = "admin"
      password = "12345678"
    }

    # Je kunt hier zelfs custom cloud-init userdata of timezones meegeven
    # (Afhankelijk van wat de Proxmox provider ondersteunt in jouw versie)
  }
}