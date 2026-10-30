output "summary" {
  value = {
    container       = var.steps.launch ? local.container_name : null
    ipv4_address    = try(lxd_instance.dev[0].ipv4_address, null)
    maas_url        = try("http://${lxd_instance.dev[0].ipv4_address}:5240/MAAS", null)
    ubuntu_version  = local.ubuntu_version
    dev_profile     = local.dev_profile_name
    machine_profile = local.machine_profile_name
    networks        = local.networks
    ranges = {
      ctrl            = local.ctrl_cidr
      kvm             = local.kvm_cidr
      ipv6            = local.ipv6_cidr
      dual_stack_ipv4 = local.dual_stack_ipv4_cidr
      dual_stack_ipv6 = local.dual_stack_ipv6_cidr
    }
  }
}
