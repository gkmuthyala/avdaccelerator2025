locals {
  keyvault_name      = lower("kv-avd-${var.avdLocation}-${var.prefix}-${random_string.random.id}")
  storage_name       = lower(replace("stavd${var.prefix}${random_string.random.id}", "-", ""))
  registration_token = azurerm_virtual_desktop_host_pool_registration_info.registrationinfo.token
  tags = {
    environment = var.prefix
    source      = "https://github.com/Azure/avdaccelerator/tree/main/workload/terraform/avdbaseline"
  }
}

