variable "libvirt_uri" {
  description = "Libvirt connection URI. Use qemu:///system for a local system libvirt instance."
  type        = string
  default     = "qemu:///system"
}

variable "vm_name" {
  description = "Name of the virtual machine."
  type        = string
  default     = "k8s-control"
}

variable "vm_user" {
  description = "Login username created by cloud-init."
  type        = string
  default     = "edoardo"
}

variable "vm_memory_mb" {
  description = "Memory allocated to the VM in MiB."
  type        = number
  default     = 4096
}

variable "vm_vcpus" {
  description = "Number of virtual CPUs."
  type        = number
  default     = 2
}

variable "root_disk_size_gib" {
  description = "Size of the VM root disk in GiB."
  type        = number
  default     = 40
}

variable "libvirt_pool" {
  description = "Existing libvirt storage pool used for the image and VM volumes."
  type        = string
  default     = "default"
}

variable "libvirt_network" {
  description = "Existing libvirt virtual network used by the VM."
  type        = string
  default     = "default"
}

variable "mac_address" {
  description = "Permanent MAC address assigned to the VM network interface."
  type        = string
  default     = "52:54:00:12:34:56"
}

variable "image_url" {
  description = "Ubuntu cloud image URL. Override this for another distribution or architecture."
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key installed for the ubuntu user."
  type        = string
  default     = "~/.ssh/eagle_ed25519.pub"
}
