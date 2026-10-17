output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "storage_account_name" {
  description = "Used by the pipeline to upload the website."
  value       = azurerm_storage_account.web.name
}

output "website_url" {
  value = azurerm_storage_account.web.primary_web_endpoint
}
