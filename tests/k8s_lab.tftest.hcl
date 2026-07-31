mock_provider "libvirt" {
  override_during = plan

  mock_resource "libvirt_cloudinit_disk" {
    defaults = {
      path = "/tmp/mock-cloud-init.iso"
    }
  }

  mock_data "libvirt_domain_interface_addresses" {
    defaults = {
      interfaces = []
    }
  }
}

variables {
  ssh_public_key_path = "tests/fixtures/test_ed25519.pub"
}

run "default_two_node_lab" {
  command = plan

  assert {
    condition     = length(libvirt_domain.vm) == 2
    error_message = "The default configuration must create two virtual machines."
  }

  assert {
    condition     = length(libvirt_volume.root) == 2
    error_message = "Each node must have its own root volume."
  }

  assert {
    condition     = length(libvirt_cloudinit_disk.config) == 2
    error_message = "Each node must have its own cloud-init configuration."
  }

  assert {
    condition = {
      for key, node in local.nodes : key => node.reserved_ip
      } == {
      control_plane = "192.168.125.10"
      worker        = "192.168.125.11"
    }
    error_message = "The default node reservations are incorrect."
  }

  assert {
    condition = (
      libvirt_network.k8s_lab.ips[0].dhcp.ranges[0].start == "192.168.125.100" &&
      libvirt_network.k8s_lab.ips[0].dhcp.ranges[0].end == "192.168.125.254"
    )
    error_message = "The default DHCP range is incorrect."
  }

  assert {
    condition = toset([
      for host in libvirt_network.k8s_lab.ips[0].dhcp.hosts : "${lower(host.mac)}=${host.ip}"
      ]) == toset([
      "52:54:00:12:34:56=192.168.125.10",
      "52:54:00:12:34:57=192.168.125.11",
    ])
    error_message = "DHCP reservations must match the node MAC and IP addresses."
  }

  assert {
    condition     = strcontains(libvirt_cloudinit_disk.config["control_plane"].user_data, "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMockedTerraformTestKeyOnlyDoNotUse000000000000")
    error_message = "Cloud-init must contain the configured SSH public key."
  }
}

run "renders_ansible_inventory" {
  command = plan

  variables {
    vm_user = "cluster-admin"
  }

  assert {
    condition     = output.ansible_inventory == <<-EOT
      [k8s_control_plane]
      k8s-control-01 ansible_host=192.168.125.10 ansible_port=22

      [k8s_workers]
      k8s-worker-01 ansible_host=192.168.125.11 ansible_port=22

      [k8s_cluster:children]
      k8s_control_plane
      k8s_workers

      [all:vars]
      ansible_user=cluster-admin
      ansible_python_interpreter=/usr/bin/python3
    EOT
    error_message = "The generated Ansible inventory has unexpected content."
  }

  assert {
    condition     = output.ssh_command == "ssh cluster-admin@192.168.125.10"
    error_message = "The SSH command must use the configured user and reserved control-plane IP."
  }
}

run "rejects_duplicate_node_identity" {
  command = plan

  variables {
    worker_name        = "k8s-control-01"
    worker_mac_address = "52:54:00:12:34:56"
    worker_ip_host     = 10
  }

  expect_failures = [
    check.unique_node_names,
    check.unique_node_mac_addresses,
    check.unique_node_ip_reservations,
  ]
}

run "rejects_reversed_dhcp_range" {
  command = plan

  variables {
    libvirt_dhcp_start_host = 200
    libvirt_dhcp_end_host   = 100
  }

  expect_failures = [check.valid_dhcp_range]
}

run "rejects_reservation_inside_dynamic_pool" {
  command = plan

  variables {
    worker_ip_host = 100
  }

  expect_failures = [check.reservations_outside_dynamic_pool]
}
