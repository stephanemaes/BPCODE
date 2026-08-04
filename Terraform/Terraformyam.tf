terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.0" 
    }
  }
}

provider "proxmox" {
  endpoint  = "https://192.168.1.35:8006/"
  api_token = "terraform@pve!provider8a6722e8-1119-4b87-97b2-65c79d6b5ab1"
  insecure  = true # Zet op false als je geldige SSL-certificaten gebruikt
}

# 1. Hoofdserver (Ubuntu 22.04)
resource "proxmox_virtual_environment_vm" "hoofdserver" {
  name        = "Hoofdserver"
  description = "Aangemaakt via Terraform - Versie 1.2.0"
  node_name   = "pve" # Pas dit aan naar de naam van jouw Proxmox node
  vm_id       = 201

  clone {
    vm_id = 9000 # Het ID van je Ubuntu 22.04 Cloud-Init template
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 2048 # 2GB RAM
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.198/24"
        gateway = "192.168.1.1"
      }
    }
    
    # Optioneel: Voeg hier je SSH key toe om in te loggen
    # user_account {
    #   username = "ubuntu"
    #   keys     = ["ssh-rsa AAAAB3NzaC1yc2E..."]
    # }
  }
}

# 2. vm2 (Debian 12)
resource "proxmox_virtual_environment_vm" "vm2" {
  name        = "vm2"
  description = "Aangemaakt via Terraform - Versie 1.2.0"
  node_name   = "pve"
  vm_id       = 202

  clone {
    vm_id = 9001 # Het ID van je Debian 12 Cloud-Init template
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 2048 # 2GB RAM
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.199/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

# 3. vm3 (Debian 12)
resource "proxmox_virtual_environment_vm" "vm3" {
  name        = "vm3"
  description = "Aangemaakt via Terraform - Versie 1.2.0"
  node_name   = "pve"
  vm_id       = 203

  clone {
    vm_id = 9001 # Maakt gebruik van hetzelfde Debian 12 template als vm2
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 2048 # 2GB RAM
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.200/24"
        gateway = "192.168.1.1"
      }
    }
  }
}