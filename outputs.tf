output "container_instance_ip" {
  value       = azurerm_container_group.containergroup_atlantis.ip_address
  description = "Azure container instance ip"

}

output "waf_public_ip" {
  value       = azurerm_public_ip.atlantis.id
  description = "Azure waf public ip"
}

output "waf_whitelisted_ips" {
  value       = concat(data.github_ip_ranges.waf.hooks, var.atlantis_whitelist_ips)
  description = "list of waf whitelisted ip cidrs"
}
