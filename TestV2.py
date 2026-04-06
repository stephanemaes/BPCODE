import yaml
from proxmoxer import ProxmoxAPI
import urllib3
import time
# Onderdruk SSL waarschuwingen
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# 1. Configuratie & Authenticatie
PROXMOX_HOST = '192.168.1.35'
PROXMOX_USER = 'root@pam'
TOKEN_NAME = 'test1'
TOKEN_VALUE = '8a6722e8-1119-4b87-97b2-65c79d6b5ab1'
PROXMOX_NODE = 'pve'

# Mapping: Welke OS naam in YAML hoort bij welk Template ID in Proxmox?
OS_TEMPLATES = {
    "Ubuntu 22.04": 9000,
    "Debian 11": 9001,
    "Alpine Linux": 9002
}

proxmox = ProxmoxAPI(
    PROXMOX_HOST,
    user=PROXMOX_USER,
    token_name=TOKEN_NAME,
    token_value=TOKEN_VALUE,
    verify_ssl=False,
    timeout=120
)

def create_vms_from_yaml(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)
    
    print(f"--- Starten met uitrollen via Cloud-Init ---")
    infra_name = data.get('infrastructure', {}).get('name', 'Unknown')
    print(f"--- Starten met uitrollen van: {infra_name} ---")

    for node in data.get('infrastructure', {}).get('nodes', []):
        name = node['name']
        specs = node['specs']
        os_choice = specs.get('os')
        
        # 1. Zoek de juiste template op
        template_id = OS_TEMPLATES.get(os_choice)
        if not template_id:
            print(f"❌ Overslaan: Geen template ID gevonden voor {os_choice}")
            continue

        ram_mb = int(specs['ram'].replace('GB', '')) * 1024
        cores = int(specs['cpu'].split()[0])
        new_vmid = int(proxmox.cluster.nextid.get())

        print(f"Klonen van {os_choice} naar {name} (ID: {new_vmid})...")

        try:
            # 2. Kloon de template
            upid = proxmox.nodes(PROXMOX_NODE).qemu(template_id).clone.create(
                newid=new_vmid,
                name=name,
                full=1 # Full clone is nodig om specs later aan te passen
            )
            # 3. Wachten tot de lock op de VM weg is (polling)
            print(f"Wachten op voltooiing van kloon-taak {upid}...")
            while True:
                task_status = proxmox.nodes(PROXMOX_NODE).tasks(upid).status.get()
                
                if task_status.get("status") == "stopped":
                    if task_status.get("exitstatus") == "OK":
                        print(f"✅ Kloon klaar voor {name}.")
                        break
                    else:
                        raise Exception(f"Kloon mislukt in Proxmox: {task_status.get('exitstatus')}")
                
                # Wacht 2 seconden voor de volgende check om de API niet te overbelasten
                time.sleep(2)
            # 3. Configureer de specs en Cloud-Init
            # We voegen hier een default user en SSH sleutel toe
            proxmox.nodes(PROXMOX_NODE).qemu(new_vmid).config.set(
                memory=ram_mb,
                cores=cores,
                # Cloud-init specifieke velden:
                ciuser="admin", 
                cipassword="Welkom01!", # Optioneel: zet een wachtwoord
                ipconfig0="ip=dhcp",    # Automatisch IP via DHCP
                # sshkeys="ssh-rsa AAAA...", # Plak hier je publieke SSH key
            )

            # 4. Start de VM (optioneel)
            # proxmox.nodes(PROXMOX_NODE).qemu(new_vmid).status.start.post()
            
            print(f"✅ {name} succesvol uitgerold.")

        except Exception as e:
            print(f"❌ Fout bij {name}: {e}")

if __name__ == "__main__":
    create_vms_from_yaml('infrastructure.yml')