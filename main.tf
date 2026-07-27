resource "libvirt_volume" "ubuntu_base" {
  name   = "${var.vm_name}-base.qcow2"
  pool   = var.libvirt_pool
  target = { format = { type = "qcow2" } }

  create = {
    content = { url = var.image_url }
  }
}

resource "libvirt_volume" "root" {
  name   = "${var.vm_name}-root.qcow2"
  pool   = var.libvirt_pool
  target = { format = { type = "qcow2" } }

  capacity = var.root_disk_size_gib * 1024 * 1024 * 1024
  backing_store = {
    path   = libvirt_volume.ubuntu_base.path
    format = { type = "qcow2" }
  }
}

resource "libvirt_cloudinit_disk" "config" {
  name = "${var.vm_name}-cloudinit"

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    vm_user        = var.vm_user
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })

  meta_data = <<-EOF
    instance-id: ${var.vm_name}-cloudinit-v2
    local-hostname: ${var.vm_name}
  EOF

}

resource "libvirt_volume" "cloudinit" {
  name = "${var.vm_name}-cloudinit.iso"
  pool = var.libvirt_pool

  create = {
    content = { url = libvirt_cloudinit_disk.config.path }
  }
}

resource "libvirt_domain" "vm" {
  name        = var.vm_name
  memory      = var.vm_memory_mb
  memory_unit = "MiB"
  vcpu        = var.vm_vcpus
  type        = "kvm"

  os = {
    type            = "hvm"
    type_arch       = "x86_64"
    type_machine    = "q35"
    firmware        = "efi"
    loader          = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
    loader_readonly = "yes"
    loader_type     = "pflash"
  }

  features = {
    acpi = true
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_volume.root.pool
            volume = libvirt_volume.root.name
          }
        }
        target = { dev = "vda", bus = "virtio" }
        driver = { type = "qcow2" }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.cloudinit.pool
            volume = libvirt_volume.cloudinit.name
          }
        }
        target = { dev = "sda", bus = "sata" }
      }
    ]

    interfaces = [
      {
        type   = "network"
        mac    = { address = var.mac_address }
        model  = { type = "virtio" }
        source = { network = { network = var.libvirt_network } }
      }
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]
  }

  running = true
}
