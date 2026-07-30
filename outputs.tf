locals {
  node_ipv4_addresses = {
    for key, node in local.nodes : key => try(
      flatten([
        for interface in data.libvirt_domain_interface_addresses.vm[key].interfaces : [
          for address in interface.addrs : address.addr
          if lower(interface.hwaddr) == lower(node.mac_address) && address.type == "ipv4"
        ]
      ])[0],
      ""
    )
  }

  inventory_groups = {
    k8s_control_plane = [
      for node in values(local.nodes) : "${node.name} ansible_host=${node.reserved_ip} ansible_port=22"
      if node.role == "control-plane"
    ]
    k8s_workers = [
      for node in values(local.nodes) : "${node.name} ansible_host=${node.reserved_ip} ansible_port=22"
      if node.role == "worker"
    ]
  }

  ansible_inventory = join("\n", concat(
    ["[k8s_control_plane]"],
    local.inventory_groups.k8s_control_plane,
    ["", "[k8s_workers]"],
    local.inventory_groups.k8s_workers,
    [
      "",
      "[k8s_cluster:children]",
      "k8s_control_plane",
      "k8s_workers",
      "",
      "[all:vars]",
      "ansible_user=${var.vm_user}",
      "ansible_python_interpreter=/usr/bin/python3",
      "",
    ]
  ))
}

output "vm_name" {
  value = libvirt_domain.vm["control_plane"].name
}

output "network_name" {
  value = libvirt_network.k8s_lab.name
}

output "mac_address" {
  value = var.mac_address
}

output "ssh_command" {
  value = "ssh ${var.vm_user}@${local.nodes.control_plane.reserved_ip}"
}

output "ansible_inventory" {
  description = "Complete Ansible inventory for the Kubernetes control plane and worker."
  value       = local.ansible_inventory
}

output "nodes" {
  description = "VM identity, role, reserved address, and DHCP lease verification by stable node key."
  value = {
    for key, node in local.nodes : key => {
      name                  = libvirt_domain.vm[key].name
      role                  = node.role
      mac_address           = node.mac_address
      ip_address            = node.reserved_ip
      reserved_ip           = node.reserved_ip
      discovered_ip_address = local.node_ipv4_addresses[key]
      lease_verified        = local.node_ipv4_addresses[key] == node.reserved_ip
    }
  }
}
