locals {
  nodes = {
    control_plane = {
      role               = "control-plane"
      name               = var.vm_name
      mac_address        = var.mac_address
      memory_mb          = var.vm_memory_mb
      vcpus              = var.vm_vcpus
      root_disk_size_gib = var.root_disk_size_gib
      ip_host            = var.control_plane_ip_host
      reserved_ip        = cidrhost(var.libvirt_network_cidr, var.control_plane_ip_host)
    }
    worker = {
      role               = "worker"
      name               = var.worker_name
      mac_address        = var.worker_mac_address
      memory_mb          = var.worker_memory_mb
      vcpus              = var.worker_vcpus
      root_disk_size_gib = var.worker_root_disk_size_gib
      ip_host            = var.worker_ip_host
      reserved_ip        = cidrhost(var.libvirt_network_cidr, var.worker_ip_host)
    }
  }
}

check "unique_node_names" {
  assert {
    condition     = length(distinct([for node in values(local.nodes) : node.name])) == length(local.nodes)
    error_message = "Every node must have a unique VM name."
  }
}

check "unique_node_mac_addresses" {
  assert {
    condition     = length(distinct([for node in values(local.nodes) : lower(node.mac_address)])) == length(local.nodes)
    error_message = "Every node must have a unique MAC address."
  }
}

check "unique_node_ip_reservations" {
  assert {
    condition     = length(distinct([for node in values(local.nodes) : node.reserved_ip])) == length(local.nodes)
    error_message = "Every node must have a unique reserved IP address."
  }
}

check "valid_dhcp_range" {
  assert {
    condition     = var.libvirt_dhcp_start_host <= var.libvirt_dhcp_end_host
    error_message = "The DHCP range start host must not be greater than the end host."
  }
}

check "reservations_outside_dynamic_pool" {
  assert {
    condition = alltrue([
      for node in values(local.nodes) :
      node.ip_host < var.libvirt_dhcp_start_host || node.ip_host > var.libvirt_dhcp_end_host
    ])
    error_message = "Reserved node addresses must be outside the dynamic DHCP pool."
  }
}

resource "libvirt_network" "k8s_lab" {
  name      = var.libvirt_network
  autostart = true

  forward = {
    mode = "nat"
  }

  ips = [
    {
      address = cidrhost(var.libvirt_network_cidr, 1)
      prefix  = tonumber(split("/", var.libvirt_network_cidr)[1])

      dhcp = {
        ranges = [
          {
            start = cidrhost(var.libvirt_network_cidr, var.libvirt_dhcp_start_host)
            end   = cidrhost(var.libvirt_network_cidr, var.libvirt_dhcp_end_host)
          }
        ]

        hosts = [
          for node in values(local.nodes) : {
            name = node.name
            mac  = node.mac_address
            ip   = node.reserved_ip
          }
        ]
      }
    }
  ]
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "${var.vm_name}-base.qcow2"
  pool   = var.libvirt_pool
  target = { format = { type = "qcow2" } }

  create = {
    content = { url = var.image_url }
  }
}

resource "libvirt_volume" "root" {
  for_each = local.nodes

  name   = "${each.value.name}-root.qcow2"
  pool   = var.libvirt_pool
  target = { format = { type = "qcow2" } }

  capacity = each.value.root_disk_size_gib * 1024 * 1024 * 1024
  backing_store = {
    path   = libvirt_volume.ubuntu_base.path
    format = { type = "qcow2" }
  }
}

resource "libvirt_cloudinit_disk" "config" {
  for_each = local.nodes

  name = "${each.value.name}-cloudinit"

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    vm_user        = var.vm_user
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })

  meta_data = <<-EOF
    instance-id: ${each.value.name}-cloudinit-v2
    local-hostname: ${each.value.name}
  EOF

}

resource "libvirt_volume" "cloudinit" {
  for_each = local.nodes

  name = "${each.value.name}-cloudinit.iso"
  pool = var.libvirt_pool

  create = {
    content = { url = libvirt_cloudinit_disk.config[each.key].path }
  }
}

resource "libvirt_domain" "vm" {
  for_each = local.nodes

  name        = each.value.name
  memory      = each.value.memory_mb
  memory_unit = "MiB"
  vcpu        = each.value.vcpus
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
            pool   = libvirt_volume.root[each.key].pool
            volume = libvirt_volume.root[each.key].name
          }
        }
        target = { dev = "vda", bus = "virtio" }
        driver = { type = "qcow2" }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_volume.cloudinit[each.key].pool
            volume = libvirt_volume.cloudinit[each.key].name
          }
        }
        target = { dev = "sda", bus = "sata" }
      }
    ]

    interfaces = [
      {
        type   = "network"
        mac    = { address = each.value.mac_address }
        model  = { type = "virtio" }
        source = { network = { network = libvirt_network.k8s_lab.name } }
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

data "libvirt_domain_interface_addresses" "vm" {
  for_each = local.nodes

  domain = libvirt_domain.vm[each.key].name
  source = "lease"
}

moved {
  from = libvirt_volume.root
  to   = libvirt_volume.root["control_plane"]
}

moved {
  from = libvirt_cloudinit_disk.config
  to   = libvirt_cloudinit_disk.config["control_plane"]
}

moved {
  from = libvirt_volume.cloudinit
  to   = libvirt_volume.cloudinit["control_plane"]
}

moved {
  from = libvirt_domain.vm
  to   = libvirt_domain.vm["control_plane"]
}
