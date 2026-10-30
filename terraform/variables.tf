#
# One entry per MAAS dev environment. Each entry produces a full set:
# 4 networks, 2 profiles and (optionally) the dev container. Everything
# else (names, IP ranges, Ubuntu version) is derived from the entry.
#
variable "environments" {
  description = "MAAS dev environments, keyed by a short name (e.g. main, 36)."
  type = map(object({
    # Unique 0-254. Selects the /24s (10.10.<id>.0 etc.) and the network
    # names (mdev<id>-*). id = 0 gives config.sh's IPv4 ranges; IPv6 ranges
    # come from base_cidrs.
    id = number
    # Path to the MAAS checkout mounted at /work in the container.
    maas_src = string
    # Upstream branch, only used to derive ubuntu_version ("" = main).
    maas_branch = optional(string, "")
    # Override the Ubuntu version derived from maas_branch.
    ubuntu_version = optional(string)
    # PEM .crt to add to the container's trusted CAs.
    ca_crt_path = optional(string)
    # Override the derived network names (bridge names are limited to 15 chars).
    network_names = optional(object({
      ctrl       = optional(string)
      kvm        = optional(string)
      ipv6       = optional(string)
      dual_stack = optional(string)
    }), {})
    # Per-environment step toggles; unset values fall back to default_steps.
    steps = optional(object({
      networks  = optional(bool)
      profiles  = optional(bool)
      launch    = optional(bool)
      provision = optional(bool)
    }), {})
  }))

  validation {
    condition     = length(distinct([for e in values(var.environments) : e.id])) == length(var.environments)
    error_message = "Every environment needs a unique id."
  }

  validation {
    condition     = alltrue([for e in values(var.environments) : e.id >= 0 && e.id <= 254])
    error_message = "Environment ids must be between 0 and 254."
  }
}

variable "default_steps" {
  description = "Steps applied to every environment unless overridden in its steps."
  type = object({
    networks  = optional(bool, true)
    profiles  = optional(bool, true)
    launch    = optional(bool, true)
    provision = optional(bool, true)
  })
  default = {}
}

variable "github_id" {
  description = "GitHub id whose public ssh keys are imported into the container."
  type        = string

  validation {
    condition     = length(var.github_id) > 0
    error_message = "github_id is required to import your ssh key via ssh_import_id."
  }
}

variable "ssh_public_keys" {
  description = "Extra public keys authorized for the ubuntu user (e.g. .state/ssh/maas_dev_key.pub)."
  type        = list(string)
  default     = []
}

variable "host_uid" {
  description = "Host uid mapped to the container's ubuntu user (id -u)."
  type        = number
}

variable "host_gid" {
  description = "Host gid mapped to the container's ubuntu group (id -g)."
  type        = number
}

variable "lxd_https_address" {
  description = "core.https_address for the host LXD, so MAAS can use it as a VM host. null leaves it unmanaged."
  type        = string
  default     = "[::]:8443"
  nullable    = true
}

variable "base_cidrs" {
  description = "Base ranges each environment's /24 (IPv4) or /64 (IPv6) is carved from by id."
  type = object({
    ctrl            = optional(string, "10.10.0.0/16")
    kvm             = optional(string, "10.20.0.0/16")
    ipv6            = optional(string, "fd42:be3f:b08a::/48")
    dual_stack_ipv4 = optional(string, "10.30.0.0/16")
    dual_stack_ipv6 = optional(string, "fd42:be3f:b08b::/48")
  })
  default = {}
}
