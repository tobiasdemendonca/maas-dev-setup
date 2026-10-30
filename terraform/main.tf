resource "lxd_server" "this" {
  count = var.lxd_https_address == null ? 0 : 1

  config = {
    "core.https_address" = var.lxd_https_address
  }
}

module "env" {
  source   = "./modules/maas-dev-env"
  for_each = var.environments

  name           = each.key
  id             = each.value.id
  maas_src       = abspath(pathexpand(each.value.maas_src))
  maas_branch    = each.value.maas_branch
  ubuntu_version = each.value.ubuntu_version
  ca_crt_path    = each.value.ca_crt_path == null ? null : abspath(pathexpand(each.value.ca_crt_path))
  network_names  = each.value.network_names
  steps = merge(
    var.default_steps,
    { for k, v in each.value.steps : k => v if v != null },
  )

  github_id       = var.github_id
  ssh_public_keys = var.ssh_public_keys
  host_uid        = var.host_uid
  host_gid        = var.host_gid
  base_cidrs      = var.base_cidrs
  scripts_dir     = abspath("${path.root}/..")
}
