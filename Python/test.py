import yaml;
from proxmoxer import ProxmoxAPI

# 1. Configuratie & Authenticatie
PROXMOX_HOST = '192.168.1.35'
PROXMOX_USER = 'root@pam'
TOKEN_NAME = 'test1'
TOKEN_VALUE = '8a6722e8-1119-4b87-97b2-65c79d6b5ab1'
PROXMOX_PASSWORD = '' 
PROXMOX_NODE = 'pve' # De specifieke fysieke server in je cluster

#Initialiseer de API connectie
if len(TOKEN_VALUE) > 0 and len(TOKEN_NAME) > 0:
    proxmox = ProxmoxAPI(
        PROXMOX_HOST,
        user=PROXMOX_USER,
        token_name=TOKEN_NAME,
        token_value=TOKEN_VALUE,
        verify_ssl=False
    )
else:
    proxmox = ProxmoxAPI(
        PROXMOX_HOST, 
        user=PROXMOX_USER, 
        password=PROXMOX_PASSWORD, 
        verify_ssl=False
    )

def create_vms_from_yaml(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)
    
    infra_name = data.get('infrastructure', {}).get('name', 'Unknown')
    print(f"--- Starten met uitrollen van: {infra_name} ---")

    for node in data.get('infrastructure', {}).get('nodes', []):
        name = node['name']
        specs = node['specs']
        
        #conversie van specs naar Proxmox parameters
        ram_mb = int(specs['ram'].replace('GB', '')) * 1024
        cores = int(specs['cpu'].split()[0])
        StorageSize = int(specs['storage'].replace('GB', ''))
        print(f"VM aanmaken: {name} ({cores} cores, {ram_mb}MB RAM)...")

        try:
            proxmox.nodes(PROXMOX_NODE).qemu.create(
                vmid=int(proxmox.cluster.nextid.get()), # automatisch de volgende VMID genereren
                name=name,
                memory=ram_mb,
                cores=cores,
                net0=f"virtio,bridge=vmbr0",
                scsihw="virtio-scsi-pci",
                scsi0=f"local-lvm:{StorageSize}"
            )
            print(f"{name} succesvol aangemaakt.")
        except Exception as e:
            print(f"Fout bij {name}: {e}")

if __name__ == "__main__":
    create_vms_from_yaml('infrastructure.yml')
