terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri             = "qemu:///system"
}

# VM name and resources
variable "vm_name" {
  type            = string
  default         = "ubuntu-2404"
}

# Create storage volume (copy-on-write)
resource "libvirt_volume" "ubuntu_disk" {
  name            = "${var.vm_name}.qcow2"
  base_volume_id  = libvirt_volume.ubuntu_base.id
  pool            = "default"
  format          = "qcow2"
  size            = 42949672960
}

# Create additional storage volume
resource "libvirt_volume" "managed-disk1" {
  name            = "${var.vm_name}-managed-disk1.qcow2"
  #  base_volume_id  = libvirt_volume.ubuntu_base.id
  pool            = "default"
  format          = "qcow2"
  size            = 42949672960
}

# Base image volume
resource "libvirt_volume" "ubuntu_base" {
  name            = var.vm_name
  source          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  pool            = "default"
  format          = "qcow2"
}

# Cloud-init ISO to inject user-data
resource "libvirt_cloudinit_disk" "commoninit" {
  name            = "${var.vm_name}-cloudinit.iso"
  user_data       = data.template_file.user_data.rendered
  pool            = "default"
}

# Minimal user data for cloud-init setup
data "template_file" "user_data" {
  template        = <<EOF
#cloud-config
hostname: ${var.vm_name}

ssh_pwauth: false
allow_public_ssh_keys: true

users:
  - name: ubuntu
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    groups: users, admin
    lock_passwd: false
    passwd: $6$hoEyHGCs56ArGwAK$XTGggRyGn97UaP1SmRQVYXz/bcyUhxYRVLomV101w0SWJKF2TqpCpeQvyPmqcEHyzNgNPsdfVm2Q8q.iIIOiY.
    ssh_authorized_keys: 
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHhDDEDtMZlS6WijXJ4Fd9fH7i7e6Gd0IZGzIztC5cTE alvesmarcelocf@proton.me

package_update: true
package_upgrade: true
EOF
}

# Define the VM domain
resource "libvirt_domain" "ubuntu" {
  
  # XML injection before creating VM
  xml {
    xslt = file("xml_injection.xsl")
  }

  name            = var.vm_name
  memory          = 8192
  machine         = "q35"
  vcpu            = 2
  cpu {
    mode          = "host-passthrough"
  }

  running         = true
  cloudinit       = libvirt_cloudinit_disk.commoninit.id

  disk {
    scsi          = true
    volume_id     = libvirt_volume.ubuntu_disk.id
  }

  disk {
    scsi          = true
    volume_id     = libvirt_volume.managed-disk1.id
  }

  network_interface {
    network_name    = "default"
    addresses       = [ "192.168.122.101" ]
    mac             = "52:54:00:0A:77:5B"
  }

  console {
    type          = "pty"
    target_port   = "0"
    target_type   = "serial"
  }

  graphics {
    type          = "spice"
    listen_type   = "none"
    autoport      = true
  }

  video {
    type          = "virtio"
  }

  boot_device {
    dev           = ["hd"]
  }
}
