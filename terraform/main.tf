terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc3"
    }
  }
}
provider "proxmox" {
  # References our vars.tf file to plug in the api_url 
  pm_api_url = var.pm_api_url
  # References our secrets.tfvars file to plug in our token_id
  pm_api_token_id = var.pm_api_token_id
  # References our secrets.tfvars to plug in our token_secret 
  pm_api_token_secret = var.pm_api_token_secret
  # Default to `true` unless you have TLS working within your pve setup 
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "kubemaster" {
  count = var.master_count
  name = "kubemaster-${count.index + 1}"
  sshkeys = var.ssh_key
  target_node = var.proxmox_node
  full_clone = "true"
  qemu_os = "l26"
  
  ### or for a Clone VM operation
  clone = var.cloudinit_template_name

  # basic VM settings here. agent refers to guest agent
  tags = "cloudinit;kubemaster;noble"
  agent = 1
  balloon = 1
  os_type = "cloud-init"
  cicustom = "vendor=local:snippets/ubuntu.yaml"
  ipconfig0 = "ip=dhcp"
  ciuser = "ubuntu"
  ssh_user = "ubuntu"
  cores = 2
  sockets = 1
  cpu = "x86-64-v2-AES"
  memory = 4096
  scsihw = "virtio-scsi-pci"
  #bootdisk = "scsi0"
   
  disks {
      scsi {
        scsi0 {
          disk {
            storage = var.storage
            size = 20
            emulatessd = true
            iothread = false
            discard = true
            backup = true
            replicate = true
           }
        }
      }
      ide {
        ide3 {
          cloudinit { 
            storage = var.storage
          }
        }
      }
    }


  # if you want two NICs, just copy this whole network section and duplicate it
  network {
    model = "virtio"
    bridge = var.bridge
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

resource "proxmox_vm_qemu" "kubeworker" {
  count = var.worker_count
  name = "kubeworker-${count.index + 1}"
  sshkeys = var.ssh_key
  target_node = var.proxmox_node
  full_clone = "true"
  qemu_os = "l26"
  
  ### or for a Clone VM operation
  clone = var.cloudinit_template_name

  # basic VM settings here. agent refers to guest agent
  tags = "cloudinit;kubeworker;noble"
  agent = 1
  balloon = 1
  os_type = "cloud-init"
  cicustom = "vendor=local:snippets/ubuntu.yaml"
  ipconfig0 = "ip=dhcp"
  ciuser = "ubuntu"
  ssh_user = "ubuntu"
  cores = 2
  sockets = 1
  cpu = "x86-64-v2-AES"
  memory = 8192
  scsihw = "virtio-scsi-pci"
  #bootdisk = "scsi0"
  
  disks {
      scsi {
        scsi0 {
          disk {
            storage = var.storage
            size = 20
            emulatessd = true
            iothread = false
            discard = true
            backup = true
            replicate = true
          }
        }
      scsi1 {
          disk {
            storage = var.storage
            size = var.storage_size
            emulatessd = true
            iothread = false
            discard = true
            backup = true
            replicate = true
          }
        }      
      }
      ide {
        ide3 {
          cloudinit { 
            storage = var.storage
          }
        }
      }
    }
 
# if you want two NICs, just copy this whole network section and duplicate it
 network {
   model = "virtio"
   bridge = var.bridge
 }

 lifecycle {
   ignore_changes = [
     network,
   ]
}
  
}


# generate inventory file for Ansible
resource "local_file" "hosts" {
  content = templatefile("hosts.tpl",
    {
      kubemaster_ip = proxmox_vm_qemu.kubemaster.*.default_ipv4_address
      kubemaster_name = proxmox_vm_qemu.kubemaster.*.name
      kubeworker_ip = proxmox_vm_qemu.kubeworker.*.default_ipv4_address
      kubeworker_name = proxmox_vm_qemu.kubeworker.*.name
    }
  )
  filename = "../ansible/hosts"
}

resource "null_resource" "null" {
  triggers = {
    always_run = timestamp() # this will always run
  }

  provisioner "local-exec" {
    command = "./call_ansible.sh"
  }
}