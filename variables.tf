variable "libvirt_uri" {
  description = "Libvirt connection URI. Use qemu:///system for a local system libvirt instance."
  type        = string
  default     = "qemu:///system"
}

variable "vm_name" {
  description = "Name of the control-plane virtual machine."
  type        = string
  default     = "k8s-control-01"
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
  description = "Name of the dedicated libvirt network managed for the Kubernetes lab."
  type        = string
  default     = "k8s-lab"
}

variable "libvirt_network_cidr" {
  description = "IPv4 CIDR assigned to the dedicated Kubernetes lab network."
  type        = string
  default     = "192.168.125.0/24"

  validation {
    condition     = can(cidrnetmask(var.libvirt_network_cidr))
    error_message = "The libvirt network CIDR must be a valid IPv4 CIDR."
  }
}

variable "libvirt_dhcp_start_host" {
  description = "Host number at which the dynamic DHCP pool starts."
  type        = number
  default     = 100
}

variable "libvirt_dhcp_end_host" {
  description = "Host number at which the dynamic DHCP pool ends."
  type        = number
  default     = 254
}

variable "control_plane_ip_host" {
  description = "Host number reserved for the control-plane node within libvirt_network_cidr."
  type        = number
  default     = 10
}

variable "mac_address" {
  description = "Permanent MAC address assigned to the control-plane VM network interface."
  type        = string
  default     = "52:54:00:12:34:56"
}

variable "worker_name" {
  description = "Name of the worker virtual machine."
  type        = string
  default     = "k8s-worker-01"
}

variable "worker_memory_mb" {
  description = "Memory allocated to the worker VM in MiB."
  type        = number
  default     = 4096
}

variable "worker_vcpus" {
  description = "Number of virtual CPUs allocated to the worker VM."
  type        = number
  default     = 2
}

variable "worker_root_disk_size_gib" {
  description = "Size of the worker VM root disk in GiB."
  type        = number
  default     = 40
}

variable "worker_mac_address" {
  description = "Permanent MAC address assigned to the worker VM network interface."
  type        = string
  default     = "52:54:00:12:34:57"
}

variable "worker_ip_host" {
  description = "Host number reserved for the worker node within libvirt_network_cidr."
  type        = number
  default     = 11
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
