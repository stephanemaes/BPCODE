import yaml
from proxmoxer import ProxmoxAPI
import urllib3
import time
# Onderdruk SSL waarschuwingen
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

PROXMOX_HOST = '192.168.1.35'
PROXMOX_USER = 'root@pam'
TOKEN_NAME = 'test1'
TOKEN_VALUE = '8a6722e8-1119-4b87-97b2-65c79d6b5ab1'
PROXMOX_NODE = 'pve'

proxmox = ProxmoxAPI(
    PROXMOX_HOST,
    user=PROXMOX_USER,
    token_name=TOKEN_NAME,
    token_value=TOKEN_VALUE,
    verify_ssl=False,
    timeout=120
)