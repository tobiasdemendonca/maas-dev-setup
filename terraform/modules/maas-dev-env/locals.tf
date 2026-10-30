locals {
  # Same mapping as setup-dev-env.sh.
  ubuntu_versions = {
    "3.4" = "jammy"
    "3.5" = "jammy"
    "3.6" = "noble"
    "3.7" = "noble"
    "3.8" = "resolute"
    ""    = "resolute"
  }
  ubuntu_version = coalesce(var.ubuntu_version, lookup(local.ubuntu_versions, var.maas_branch, "unknown"))

  prefix               = "maas-${var.name}"
  container_name       = local.prefix
  dev_profile_name     = "${local.prefix}-dev"
  machine_profile_name = "${local.prefix}-machine"
  vm_host_name         = "${local.prefix}-host"
  vm_host_lxd_project  = local.prefix

  # Bridge names are kernel interface names: max 15 characters.
  networks = {
    ctrl       = coalesce(var.network_names.ctrl, "mdev${var.id}-ctrl")
    kvm        = coalesce(var.network_names.kvm, "mdev${var.id}-kvm")
    ipv6       = coalesce(var.network_names.ipv6, "mdev${var.id}-v6")
    dual_stack = coalesce(var.network_names.dual_stack, "mdev${var.id}-ds")
  }

  ctrl_cidr            = cidrsubnet(var.base_cidrs.ctrl, 8, var.id)
  kvm_cidr             = cidrsubnet(var.base_cidrs.kvm, 8, var.id)
  ipv6_cidr            = cidrsubnet(var.base_cidrs.ipv6, 16, var.id)
  dual_stack_ipv4_cidr = cidrsubnet(var.base_cidrs.dual_stack_ipv4, 8, var.id)
  dual_stack_ipv6_cidr = cidrsubnet(var.base_cidrs.dual_stack_ipv6, 16, var.id)

  # Gateway (host) addresses, as config.sh's MAAS_*_IP_RANGE values.
  ctrl_gateway            = cidrhost(local.ctrl_cidr, 1)
  kvm_gateway             = cidrhost(local.kvm_cidr, 1)
  ipv6_gateway            = cidrhost(local.ipv6_cidr, 1)
  dual_stack_ipv4_gateway = cidrhost(local.dual_stack_ipv4_cidr, 1)
  dual_stack_ipv6_gateway = cidrhost(local.dual_stack_ipv6_cidr, 1)

  vendor_data = "#cloud-config\n${yamlencode({
    packages            = ["git", "build-essential", "jq"]
    ssh_authorized_keys = var.ssh_public_keys
    ssh_import_id       = ["gh:${var.github_id}"]
    runcmd = [
      "cat /dev/zero | ssh-keygen -q -N \"\"",
      "loginctl enable-linger ubuntu",
    ]
  })}"

  # Environment for setup-region-via-ssh.bash / add-ca-cert.bash.
  script_env = {
    HOME                       = "/home/ubuntu"
    USER                       = "ubuntu"
    MAAS_CONTROL_IP_RANGE      = local.ctrl_gateway
    MAAS_MANAGEMENT_IP_RANGE   = local.kvm_gateway
    MAAS_IPV6_IP_RANGE         = local.ipv6_gateway
    MAAS_DUAL_STACK_IPV4_RANGE = local.dual_stack_ipv4_gateway
    MAAS_DUAL_STACK_IPV6_RANGE = local.dual_stack_ipv6_gateway
    MAAS_VMHOST_NAME           = local.vm_host_name
    MAAS_VMHOST_LXD_PROJECT    = local.vm_host_lxd_project
  }
}
