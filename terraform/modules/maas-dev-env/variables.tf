variable "name" {
  description = "Environment name; prefixes the container and profile names."
  type        = string
}

variable "id" {
  description = "Unique environment id (0-254); selects network names and IP ranges."
  type        = number
}

variable "maas_src" {
  description = "Absolute path to the MAAS checkout mounted at /work."
  type        = string
}

variable "maas_branch" {
  description = "Upstream MAAS branch, used to derive the Ubuntu version (\"\" = main)."
  type        = string
  default     = ""
}

variable "ubuntu_version" {
  description = "Overrides the Ubuntu version derived from maas_branch."
  type        = string
  default     = null
}

variable "ca_crt_path" {
  description = "Absolute path to a PEM .crt added to the container's trusted CAs."
  type        = string
  default     = null
}

variable "network_names" {
  description = "Overrides for the derived network names."
  type = object({
    ctrl       = optional(string)
    kvm        = optional(string)
    ipv6       = optional(string)
    dual_stack = optional(string)
  })
  default = {}
}

variable "steps" {
  description = "Which parts of the environment to create. provision only applies when launch is set."
  type = object({
    networks  = bool
    profiles  = bool
    launch    = bool
    provision = bool
  })

}

variable "github_id" {
  type = string
}

variable "ssh_public_keys" {
  type = list(string)
}

variable "host_uid" {
  type = number
}

variable "host_gid" {
  type = number
}

variable "base_cidrs" {
  type = object({
    ctrl            = string
    kvm             = string
    ipv6            = string
    dual_stack_ipv4 = string
    dual_stack_ipv6 = string
  })
}

variable "scripts_dir" {
  description = "Directory holding setup-region-via-ssh.bash and add-ca-cert.bash."
  type        = string
}
