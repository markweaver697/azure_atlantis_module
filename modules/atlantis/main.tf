locals {
  subnet1                        = cidrsubnet(var.vnet_cidr, 1, 0)
  subnet2                        = cidrsubnet(var.vnet_cidr, 1, 1)
  subnets                        = (concat([local.subnet1], [local.subnet2]))
  subnet_names                   = ["atlantis_backend", "atlantis_frontend"]
  backend_address_pool_name      = "${azurerm_virtual_network.atlantis.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.atlantis.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.atlantis.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.atlantis.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.atlantis.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.atlantis.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.atlantis.name}-rdrcfg"
  ssl_certificate_name           = "atlantis"
}


# Atlantis  Resource group
resource "azurerm_resource_group" "atlantis" {
  name     = "atlantis"
  location = var.location
}


#Atlantis network resources
resource "azurerm_virtual_network" "atlantis" {
  name                = azurerm_resource_group.atlantis.name
  location            = azurerm_resource_group.atlantis.location
  resource_group_name = azurerm_resource_group.atlantis.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.atlantis.name
  virtual_network_name = azurerm_virtual_network.atlantis.name
  address_prefixes     = [local.subnet1]
}


resource "azurerm_subnet" "backend" {
  name                                           = "backend"
  resource_group_name                            = azurerm_resource_group.atlantis.name
  virtual_network_name                           = azurerm_virtual_network.atlantis.name
  address_prefixes                               = [local.subnet2]
  enforce_private_link_endpoint_network_policies = true
  service_endpoints                              = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
  delegation {
    name = "acidelegationservice"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
  lifecycle {
    ignore_changes = [delegation.0.service_delegation.0.actions]
  }
}

#atlantis app_gateway config
resource "azurerm_public_ip" "atlantis" {
  name                = "atlantis-pip"
  resource_group_name = azurerm_resource_group.atlantis.name
  location            = azurerm_resource_group.atlantis.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.subscription_name}-atlantis"
}


resource "azurerm_application_gateway" "network" {
  name                              = "atlantis-appgateway"
  resource_group_name               = azurerm_resource_group.atlantis.name
  location                          = azurerm_resource_group.atlantis.location
  firewall_policy_id                = azurerm_web_application_firewall_policy.atlantis.id
  force_firewall_policy_association = true

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "atlantis"
    subnet_id = azurerm_subnet.frontend.id
  }

  dynamic "frontend_port" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name = local.frontend_port_name
      port = 443
    }
  }

  dynamic "frontend_port" {
    for_each = var.enable_ssl ? [] : [1]
    content {
      name = local.frontend_port_name
      port = 80
    }
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.atlantis.id
  }

  backend_address_pool {
    name  = local.backend_address_pool_name
    fqdns = [azurerm_container_group.containergroup_atlantis.ip_address]
  }

  dynamic "ssl_certificate" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name     = local.ssl_certificate_name
      data     = filebase64("${path.root}/${var.ssl_pfx_file}")
      password = var.ssl_pfx_file_password
    }
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 4141
    protocol              = "Http"
    request_timeout       = 60
    host_name             = azurerm_container_group.containergroup_atlantis.ip_address
  }


  dynamic "http_listener" {
    for_each = var.enable_ssl ? [1] : []
    content {
      name                           = local.listener_name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.frontend_port_name
      protocol                       = "Https"
      ssl_certificate_name           = local.ssl_certificate_name
    }
  }

  dynamic "http_listener" {
    for_each = var.enable_ssl ? [] : [1]
    content {
      name                           = local.listener_name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.frontend_port_name
      protocol                       = "Http"
    }
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 10
  }
}


resource "azurerm_web_application_firewall_policy" "atlantis" {
  name                = "atlantis-wafpolicy"
  resource_group_name = azurerm_resource_group.atlantis.name
  location            = azurerm_resource_group.atlantis.location

  custom_rules {
    name      = "Rule1"
    priority  = 1
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = true
      match_values       = concat(data.github_ip_ranges.waf.hooks, var.atlantis_whitelist_ips)
    }
    action = "Block"
  }

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = false
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.1"
    }
  }
}


#Atlantis container group config
resource "azurerm_network_profile" "containergroup_profile" {
  name                = "atlantis-acg-profile"
  location            = azurerm_resource_group.atlantis.location
  resource_group_name = azurerm_resource_group.atlantis.name

  container_network_interface {
    name = "atlantis-aci-nic"

    ip_configuration {
      name      = "atlantisaciipconfig"
      subnet_id = azurerm_subnet.backend.id
    }
  }
}

resource "azurerm_container_group" "containergroup_atlantis" {
  name                = "atlantis"
  location            = azurerm_resource_group.atlantis.location
  resource_group_name = azurerm_resource_group.atlantis.name
  ip_address_type     = "Private"
  os_type             = "Linux"
  network_profile_id  = azurerm_network_profile.containergroup_profile.id
  restart_policy      = "OnFailure"


  dynamic "container" {
    for_each = var.create_and_attach_storage ? [] : [1]
    content {
      name = "atlantis"
      #image  = "ghcr.io/runatlantis/atlantis:latest"
      image  = "infracost/infracost-atlantis:latest"
      cpu    = "1.0"
      memory = "2.0"
      ports {
        port     = 4141
        protocol = "TCP"
      }

      secure_environment_variables = {
        ATLANTIS_GH_USER           = var.atlantis_gh_user
        ATLANTIS_GH_TOKEN          = var.atlantis_gh_token
        ATLANTIS_GH_WEBHOOK_SECRET = var.atlantis_gh_webhook_secret
        ATLANTIS_REPO_WHITELIST    = var.atlanits_repo_whitelist
        ARM_CLIENT_ID              = azuread_service_principal.atlantis.application_id
        ARM_TENANT_ID              = data.azurerm_subscription.current.tenant_id
        ARM_SUBSCRIPTION_ID        = data.azurerm_subscription.current.subscription_id
        ATLANTIS_WEB_BASIC_AUTH    = var.atlantis_ui_basic_auth
        ATLANTIS_WEB_USERNAME      = var.atlantis_ui_user
        ATLANTIS_WEB_PASSWORD      = var.atlantis_ui_pass
        GITHUB_TOKEN               = var.atlantis_gh_token
        INFRACOST_API_KEY          = var.infracost_api_key
        ATLANTIS_REPO_CONFIG_JSON  = var.infracost_repos_json
      }
    }
  }

  dynamic "container" {
    for_each = var.create_and_attach_storage ? [1] : []
    content {
      name = "atlantis"
      #image  = "runatlantis/atlantis:latest"
      image  = "infracost/infracost-atlantis:latest"
      cpu    = "1.0"
      memory = "2.0"
      ports {
        port     = 4141
        protocol = "TCP"
      }

      secure_environment_variables = {
        ATLANTIS_GH_USER           = var.atlantis_gh_user
        ATLANTIS_GH_TOKEN          = var.atlantis_gh_token
        ATLANTIS_GH_WEBHOOK_SECRET = var.atlantis_gh_webhook_secret
        ATLANTIS_REPO_WHITELIST    = var.atlanits_repo_whitelist
        ARM_CLIENT_ID              = azuread_service_principal.atlantis.application_id
        ARM_CLIENT_SECRET          = azuread_service_principal_password.atlantis.value
        ARM_TENANT_ID              = data.azurerm_subscription.current.tenant_id
        ARM_SUBSCRIPTION_ID        = data.azurerm_subscription.current.subscription_id
        ARM_ACCESS_KEY             = azurerm_storage_account.atlantis_storage[0].primary_access_key
        ATLANTIS_WEB_BASIC_AUTH    = var.atlantis_ui_basic_auth
        ATLANTIS_WEB_USERNAME      = var.atlantis_ui_user
        ATLANTIS_WEB_PASSWORD      = var.atlantis_ui_pass
        GITHUB_TOKEN               = var.atlantis_gh_token
        INFRACOST_API_KEY          = var.infracost_api_key
        ATLANTIS_REPO_CONFIG_JSON  = var.infracost_repos_json
      }

      dynamic "volume" {
        for_each = var.create_and_attach_storage ? [1] : []
        content {
          name                 = "atlantis"
          read_only            = false
          mount_path           = "/mnt/atlantis-data"
          share_name           = azurerm_storage_share.container_share[0].name
          storage_account_name = azurerm_storage_account.atlantis_storage[0].name
          storage_account_key  = azurerm_storage_account.atlantis_storage[0].primary_access_key
        }
      }
    }
  }
}

#atlantis blob_storage 
resource "azurerm_storage_account" "atlantis_storage" {
  count                    = var.create_and_attach_storage ? 1 : 0
  name                     = "${var.subscription_name}atlantisstore"
  resource_group_name      = azurerm_resource_group.atlantis.name
  location                 = azurerm_resource_group.atlantis.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

## this will be mapped to the container instance 
resource "azurerm_storage_share" "container_share" {
  count                = var.create_and_attach_storage ? 1 : 0
  name                 = "atlantis-data"
  storage_account_name = azurerm_storage_account.atlantis_storage[0].name
  quota                = 100
}

##this is for stroing terrafrom statefile configurations 
resource "azurerm_storage_container" "atlantis_container" {
  count                = var.create_and_attach_storage ? 1 : 0
  name                 = "atlantis-tf-files"
  storage_account_name = azurerm_storage_account.atlantis_storage[0].name
}

#Atlantis IAM resources 
data "azuread_client_config" "current" {}
data "azurerm_subscription" "current" {}
data "github_ip_ranges" "waf" {}

resource "azuread_application" "atlantis" {
  display_name = "atlantis"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "atlantis" {
  application_id               = azuread_application.atlantis.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "atlantis" {
  service_principal_id = azuread_service_principal.atlantis.object_id
}

resource "azurerm_role_assignment" "aci" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = "${data.azurerm_subscription.current.id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
  principal_id       = azuread_service_principal.atlantis.id
}
