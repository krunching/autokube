#! /bin/bash

# Change Parameters matching your environment 
STORAGE="external-lvm"
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhdd4M03kGHIoHsYOL/htqHnCQ67gQ8bMGil9rupLrn malte.krause@krunching.de"
TF_USERPASS="terraform"

set -x
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qemu-img resize noble-server-cloudimg-amd64.img 20G
qm create 9000 --name "ubuntu-2404-ci" --ostype l26 \
    --memory 2048 --balloon 1 \
    --agent 1 \
    --cpu x86-64-v2-AES --cores 1 --numa 0 \
    --net0 virtio,bridge=vmbr0,mtu=1
qm importdisk 9000 noble-server-cloudimg-amd64.img $STORAGE
qm set 9000 --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-9000-disk-0,discard=on,ssd=1
qm set 9000 --ide2 $STORAGE:cloudinit
qm set 9000 --boot order=scsi0

mkdir /var/lib/vz/snippets
cat << EOF | tee /var/lib/vz/snippets/ubuntu.yaml
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

qm set 9000 --cicustom "vendor=local:snippets/ubuntu.yaml"
qm set 9000 --tags ubuntu-template,noble,cloudinit
qm set 9000 --ciuser ubuntu
qm set 9000 --sshkeys $SSH_KEY
qm set 9000 --ipconfig0 ip=dhcp
qm template 9000

# Script derived from https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs/blob/main/samples/ubuntu/ubuntu-noble-cloudinit.sh

# Prepare terraform role and user
pveum role add terraformProv -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"
pveum user add terraform-prov@pve --password $TF_USERPASS
pveum aclmod / -user terraform-prov@pve -role terraformProv

# Taken from https://4sysops.com/archives/clone-proxmox-vms-with-terraform/
