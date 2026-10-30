output "environments" {
  description = "Per-environment names, addresses and MAAS URL."
  value       = { for k, m in module.env : k => m.summary }
}
