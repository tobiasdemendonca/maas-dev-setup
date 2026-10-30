resource "lxd_profile" "dev" {
  count = var.steps.profiles ? 1 : 0

  name        = local.dev_profile_name
  description = "MAAS ${var.name}: build environment for MAAS"

  config = {
    "raw.idmap"        = "uid ${var.host_uid} 1000\ngid ${var.host_gid} 1000"
    "user.vendor-data" = local.vendor_data
  }

  device {
    name = "work"
    type = "disk"
    properties = {
      source = var.maas_src
      path   = "/work"
    }
  }

  dynamic "device" {
    for_each = {
      eth0 = local.network_refs.ctrl
      eth1 = local.network_refs.kvm
      eth2 = local.network_refs.ipv6
      eth3 = local.network_refs.dual_stack
    }
    content {
      name = device.key
      type = "nic"
      properties = {
        name    = device.key
        network = device.value
      }
    }
  }
}

resource "lxd_profile" "machine" {
  count = var.steps.profiles ? 1 : 0

  name        = local.machine_profile_name
  description = "MAAS ${var.name}: MAAS-managed VMs on ${local.network_refs.kvm}"

  config = {
    "boot.mode"     = "uefi-nosecureboot"
    "limits.cpu"    = "2"
    "limits.memory" = "6GiB"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      name            = "eth0"
      nictype         = "bridged"
      parent          = local.network_refs.kvm
      "boot.priority" = "1"
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path            = "/"
      pool            = "default"
      size            = "8GB"
      "boot.priority" = "0"
    }
  }
}
