module "atlantis" {
  vnet_cidr                  = "10.100.0.0/24"
  source                     = "..\\modules\\atlantis"
  location                   = "eastus"
  subscription_name          = "default"
  atlantis_gh_user           = "your_github_user"
  atlantis_gh_token          = "your_github_token"
  atlantis_gh_webhook_secret = "a_webhook_secret"
  atlanits_repo_whitelist    = "github.com/use_or_org/repo"
  az_subscription_id         = "000000-0000-0000-0000-0000000"
  az_tenant_id               = "000000-0000-0000-0000-0000000"
  atlantis_whitelist_ips     = ["8.8.8.8/32","4.2.2.0/24"]
  infracost_api_key          = "your_infactor_api_key"
  enable_ssl                 = true
  ssl_pfx_file               = "your_cert_file.pfx"
  ssl_pfx_file_password      = "your_cert_file_password"
}