resource "lxd_instance" "dev" {
  count = var.steps.launch ? 1 : 0

  name     = local.container_name
  image    = "ubuntu:${local.ubuntu_version}"
  profiles = ["default", try(lxd_profile.dev[0].name, local.dev_profile_name)]

  wait_for {
    type = "ipv4"
  }

  file {
    source_path        = "${var.scripts_dir}/setup-region-via-ssh.bash"
    target_path        = "/opt/maas-dev/setup-region.bash"
    mode               = "0755"
    create_directories = true
  }

  dynamic "file" {
    for_each = var.ca_crt_path == null ? [] : [var.ca_crt_path]
    content {
      source_path = file.value
      target_path = "/usr/local/share/ca-certificates/${basename(file.value)}"
      mode        = "0644"
    }
  }

  dynamic "file" {
    for_each = var.ca_crt_path == null ? [] : [var.ca_crt_path]
    content {
      source_path        = "${var.scripts_dir}/add-ca-cert.bash"
      target_path        = "/opt/maas-dev/add-ca-cert.bash"
      mode               = "0755"
      create_directories = true
    }
  }

  # Keys are prefixed to keep the intended order: wait for cloud-init, add
  # the CA (setup pulls from hosts that may need it), then set up MAAS.
  execs = {
    "10-cloud-init" = {
      command = ["cloud-init", "status", "--wait"]
      trigger = "once"
    }
    "20-ca-cert" = {
      command     = ["/opt/maas-dev/add-ca-cert.bash"]
      enabled     = var.ca_crt_path != null
      trigger     = "once"
      uid         = 1000
      gid         = 1000
      environment = merge(local.script_env, { base_filename = basename(coalesce(var.ca_crt_path, "none")) })
    }
    "30-setup-region" = {
      command     = ["/opt/maas-dev/setup-region.bash"]
      enabled     = var.steps.provision
      trigger     = "once"
      uid         = 1000
      gid         = 1000
      working_dir = "/home/ubuntu"
      environment = local.script_env
    }
  }

  timeouts = {
    # make install-dependencies + make + make doc take a while.
    create = "90m"
  }

  lifecycle {
    precondition {
      condition     = local.ubuntu_version != "unknown"
      error_message = "maas_branch '${var.maas_branch}' has no known Ubuntu version mapping; set ubuntu_version."
    }
  }
}
