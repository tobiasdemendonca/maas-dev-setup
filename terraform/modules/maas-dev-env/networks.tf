resource "lxd_network" "ctrl" {
  count = var.steps.networks ? 1 : 0

  name        = local.networks.ctrl
  description = "MAAS ${var.name}: region/rack control network"
  config = {
    "dns.domain"       = local.networks.ctrl
    "ipv4.address"     = "${local.ctrl_gateway}/24"
    "ipv4.dhcp"        = "true"
    "ipv4.dhcp.ranges" = "${cidrhost(local.ctrl_cidr, 16)}-${cidrhost(local.ctrl_cidr, 31)}"
    "ipv4.nat"         = "true"
    "ipv6.address"     = "none"
  }
}

resource "lxd_network" "kvm" {
  count = var.steps.networks ? 1 : 0

  name        = local.networks.kvm
  description = "MAAS ${var.name}: MAAS-managed VMs (MAAS serves DHCP)"
  config = {
    "ipv4.address" = "${local.kvm_gateway}/24"
    "ipv4.dhcp"    = "false"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}

resource "lxd_network" "ipv6" {
  count = var.steps.networks ? 1 : 0

  name        = local.networks.ipv6
  description = "MAAS ${var.name}: IPv6 only network"
  config = {
    "ipv4.address" = "none"
    "ipv6.address" = "${local.ipv6_gateway}/64"
    "ipv6.dhcp"    = "false"
    "ipv6.nat"     = "true"
  }
}

resource "lxd_network" "dual_stack" {
  count = var.steps.networks ? 1 : 0

  name        = local.networks.dual_stack
  description = "MAAS ${var.name}: IPv4 and IPv6 network"
  config = {
    "ipv4.address" = "${local.dual_stack_ipv4_gateway}/24"
    "ipv4.dhcp"    = "false"
    "ipv4.nat"     = "true"
    "ipv6.address" = "${local.dual_stack_ipv6_gateway}/64"
    "ipv6.dhcp"    = "false"
    "ipv6.nat"     = "true"
  }
}

locals {
  # Reference the managed networks when created (for dependency ordering),
  # otherwise fall back to the names of networks that already exist.
  network_refs = {
    ctrl       = try(lxd_network.ctrl[0].name, local.networks.ctrl)
    kvm        = try(lxd_network.kvm[0].name, local.networks.kvm)
    ipv6       = try(lxd_network.ipv6[0].name, local.networks.ipv6)
    dual_stack = try(lxd_network.dual_stack[0].name, local.networks.dual_stack)
  }
}
