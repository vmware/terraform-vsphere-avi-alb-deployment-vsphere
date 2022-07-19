output "controllers" {
  description = "AVI Controller Information"
  value = ([for key, value in local.controller_info : merge(
    { "name" = key },
    { "private_ip_address" = value }
    )
    ]
  )
}
output "gslb_ip" {
  description = "The IP Address of AVI Controller Information"
  value       = var.controller_ha ? var.controller_ip[3] : var.controller_ip[0]
}