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
  default         = "archlinux"
}

# Create storage volume (copy-on-write)
resource "libvirt_volume" "archlinux_disk" {
  name            = "${var.vm_name}.qcow2"
  base_volume_id  = libvirt_volume.archlinux_base.id
  pool            = "default"
  format          = "qcow2"
  size            = 21474836480
}

# Base image volume
resource "libvirt_volume" "archlinux_base" {
  name            = var.vm_name
  source          = "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
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
  - name: archlinux
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    groups: wheel
    lock_passwd: false
    passwd: $6$hoEyHGCs56ArGwAK$XTGggRyGn97UaP1SmRQVYXz/bcyUhxYRVLomV101w0SWJKF2TqpCpeQvyPmqcEHyzNgNPsdfVm2Q8q.iIIOiY.
    ssh_authorized_keys: 
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHhDDEDtMZlS6WijXJ4Fd9fH7i7e6Gd0IZGzIztC5cTE alvesmarcelocf@proton.me

package_update: true
package_upgrade: true
EOF
}

# Define the VM domain
resource "libvirt_domain" "archlinux" {
  
  # Add Spice channels and set SATA for disks
  xml {
    xslt = file("add_spicevmc_and_set_sata_disk.xsl")
  }

  name            = var.vm_name
  memory          = 8192
  machine         = "q35"
  vcpu            = 2
  cpu {
    mode          = "host-passthrough"
  }

  running         = false
  cloudinit       = libvirt_cloudinit_disk.commoninit.id

  disk {
    scsi          = true
    volume_id     = libvirt_volume.archlinux_disk.id
  }

  network_interface {
    network_name  = "default"
    addresses     = [ "192.168.122.100" ]
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
