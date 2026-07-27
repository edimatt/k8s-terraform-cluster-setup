output "vm_name" {
  value = libvirt_domain.vm.name
}

output "network_name" {
  value = var.libvirt_network
}

output "mac_address" {
  value = var.mac_address
}

output "ssh_command" {
  value = "ssh ${var.vm_user}@<vm-ip>"
}
