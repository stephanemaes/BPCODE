terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.0"
    }
  }
}

locals {
  # 1. Lees het YAML-bestand in
  yaml_data = yamldecode(file("${path.module}/infraTerra.yml"))

  # 2. Zet de lijst met nodes om naar een map voor for_each
  nodes = { for node in local.yaml_data.nodes : node.name => node }

  # 3. Koppel de OS-naam uit de YAML aan het juiste Template ID in Proxmox
  # Pas de VM ID's (9000, 9001, etc.) aan naar jouw eigen templates!
  templates = {
    "Debian 12"    = 9000
    "Ubuntu 22.04" = 9001
  }
}

provider "proxmox" {
  endpoint  = "https://192.168.1.35:8006/"
  api_token = "root@pam!test1=8a6722e8-1119-4b87-97b2-65c79d6b5ab1"
  insecure  = true # Zet op false als je geldige SSL-certificaten gebruikt
}

resource "proxmox_virtual_environment_vm" "dynamic_vms" {
  for_each = local.nodes

  name        = each.value.name
  description = "Beheerd via Terraform - ${each.value.specs.os}"
  node_name   = "pve" # Pas aan naar de naam van jouw Proxmox-knooppunt
  vm_id       = each.value.vm_id

  # KLONEN VAN KNS / TEMPLATE
  clone {
    # Zoekt automatisch het ID op in de local.templates map op basis van specs.os uit YAML
    vm_id = local.templates[each.value.specs.os]
  }

  # CPU CONFIGURATIE
  cpu {
    cores = tonumber(each.value.specs.cpu)
  }

  # GEHEUGEN CONFIGURATIE (In MB)
  memory {
    dedicated = tonumber(each.value.specs.ram)
  }

  # NETWERK CONFIGURATIE
  network_device {
    bridge = lookup(each.value.network, "bridge", "vmbr0")
  }

  # DYNAMISCHE DISKS (Maakt scsi0, scsi1, etc. aan op basis van de lijst in YAML)
  dynamic "disk" {
    for_each = lookup(each.value.specs, "disks", [])
    content {
      size         = tonumber(disk.value.size)
      datastore_id = disk.value.storage
      interface    = "scsi${disk.key}"
    }
  }

  # CLOUD-INIT CONFIGURATIE (IP, Gateway, Gebruiker)
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.network.ip_address}/24"
        gateway = each.value.network.gateway
      }
    }

    user_account {
      username = "admin"
      password = "12345678"
    }
  }
}