<!-- BEGIN_TF_DOCS -->
## Requirements
* You will need an Azure account.\\n
* You will need a github account.  You will have to setup an access token for Atlantis to use for access to github.  You will also need to setup a webhook secret for github to securely communicate with Atlantis.\\n
* You can review the documentation here https://www.runatlantis.io/docs/access-credentials.html#create-an-atlantis-user-optional \\n
* You will need an infracost API Key. You can install Infracost locally by downloading https://infracost.io/ and running the following command 'infracost register'  to get an API key.\\n

## Notes
I started this as a module to learn terraform and Azure better.\\n
if I am doing something wrong or if it can be done better please feel free to let me know.\\n
markweaver697@gmail.com\\n

## What this module is doing
* Creates a resource group for all atlantis resources \\n
* Creates a vnet with  2 subnets and provisions the backend subnet for container instance delegation and a blob storage service endpoint. \\n
* Uses the Github provider to get a list of IP's where webhooks will be sent from Github. It then adds those to a firewall policy associated with the Web Application Firewall v2.\\n
* Creates a Azure application and service principal with contributor access to be used with the Atlantis deployment\\n
* Creates a Container instance with the Infracost and Atlantis Docker image.  You can download and edit the module and put the runatlantis/atlantis:latest image if you do not want infracost comments on your pull requests\\n
* Atlantis repos_json is configured to run an infracost evaluation and a terraform fmt check on all pull requests.  you can add more workflow actions by adding them to the repos_json in infracost_repos_json variable. 
* Create a Web Application Firewall with a public IP and firewall policy that whitelists any IP CIDRs from 'input_atlantis_whitelist_ip' variable and the collected Github public IP's that send webhooks\\n
* Optional feature to create and attach a Azure blob storage account and map the storage to "/mnt/atlantis-data" on the container instance. This feature can be enabled by answering true to the 'input_mount_blob_storage_on_container' variable \\n
* [PLEASE READ!] Optional feature to secure Atlantis UI with a basic username/password authentication.  This feature seems to be broken in the current atlantis images. it is set to default'false' at this time.  you can use variable 'input_atlantis_ui_basic_auth' set to true to enable\\\n

## Quick self signed certificate
Source: https://www.baeldung.com/openssl-self-signed-cert 

* You will need openssl (use linux, macos, wsl). You can create one in powershell as well but I have not included that here.\\n
* Let's create a password-protected, 2048-bit RSA private key (domain.key) with the openssl command:\\n
`openssl genrsa -out domain.key 2048`\\n
* Let's create a CSR (domain.csr) from our existing private key:]\\n
`openssl req -key domain.key -new -out domain.csr`\\n
* Let's create a self-signed certificate (domain.crt) with our existing private key and CSR:\\n
`openssl x509 -signkey domain.key -in domain.csr -req -days 365 -out domain.crt`\\n
* We'll use the following command to take our private key and certificate, and then combine them into a PKCS12 file:\\n
`openssl pkcs12 -inkey domain.key -in domain.crt -export -out domain.pfx`\\n

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | n/a |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |
| <a name="provider_github"></a> [github](#provider\_github) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.atlantis](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_service_principal.atlantis](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azuread_service_principal_password.atlantis](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal_password) | resource |
| [azurerm_application_gateway.network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway) | resource |
| [azurerm_container_group.containergroup_atlantis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_group) | resource |
| [azurerm_network_profile.containergroup_profile](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_profile) | resource |
| [azurerm_public_ip.atlantis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.atlantis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.aci](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.atlantis_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.atlantis_container](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_share.container_share](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share) | resource |
| [azurerm_subnet.backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.frontend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.atlantis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_web_application_firewall_policy.atlantis](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/web_application_firewall_policy) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [github_ip_ranges.waf](https://registry.terraform.io/providers/hashicorp/github/latest/docs/data-sources/ip_ranges) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atlanits_repo_whitelist"></a> [atlanits\_repo\_whitelist](#input\_atlanits\_repo\_whitelist) | the address for the github repo. do not include http://. just 'github.com/org/repo' is needed | `string` | `""` | no |
| <a name="input_atlantis_gh_token"></a> [atlantis\_gh\_token](#input\_atlantis\_gh\_token) | The github token to use for the access to the github repo | `string` | `""` | no |
| <a name="input_atlantis_gh_user"></a> [atlantis\_gh\_user](#input\_atlantis\_gh\_user) | The github user to use for the access to the github repo | `string` | `""` | no |
| <a name="input_atlantis_gh_webhook_secret"></a> [atlantis\_gh\_webhook\_secret](#input\_atlantis\_gh\_webhook\_secret) | The github webhook to use for the access to the github | `string` | `""` | no |
| <a name="input_atlantis_ui_basic_auth"></a> [atlantis\_ui\_basic\_auth](#input\_atlantis\_ui\_basic\_auth) | if you answer true this will enable a user/pass defined in atlantis\_ui\_user and atlantis\_ui\_pass variables as a basic auth to the atlantis UI. However right now this feature seems to be broken on current docker images. don't enable this until it's fixed | `bool` | `false` | no |
| <a name="input_atlantis_ui_pass"></a> [atlantis\_ui\_pass](#input\_atlantis\_ui\_pass) | the password to use in the atlantis\_ui\_pass auth | `string` | `""` | no |
| <a name="input_atlantis_ui_user"></a> [atlantis\_ui\_user](#input\_atlantis\_ui\_user) | the user name to use in the atlantis\_ui\_user auth | `string` | `""` | no |
| <a name="input_atlantis_whitelist_ips"></a> [atlantis\_whitelist\_ips](#input\_atlantis\_whitelist\_ips) | We are protecting Atlantis with a WAFv2 App gateway. Git webhook IP's are being automatically added to the WAFv2 policy. Here you should include any public IP CIDR's you want to access the atlantis UI with . I.E. Home connection, Data centers, offices, etc. | `list(string)` | <pre>[<br>  ""<br>]</pre> | no |
| <a name="input_az_subscription_id"></a> [az\_subscription\_id](#input\_az\_subscription\_id) | the subscription ID for Azure | `string` | `""` | no |
| <a name="input_az_tenant_id"></a> [az\_tenant\_id](#input\_az\_tenant\_id) | the tenant\_id for azure subscription | `string` | `""` | no |
| <a name="input_create_and_attach_storage"></a> [create\_and\_attach\_storage](#input\_create\_and\_attach\_storage) | if you do not want blob storage created and mapped to the container change this to false | `bool` | `true` | no |
| <a name="input_enable_ssl"></a> [enable\_ssl](#input\_enable\_ssl) | if you answer true this will enable SSL config for atlantis and the WAFv2. you will need pfx, pem and crt files. you can create your own self signed for testing but be sure to disable SSL verification on github webhook | `bool` | `false` | no |
| <a name="input_infracost_api_key"></a> [infracost\_api\_key](#input\_infracost\_api\_key) | the api key from infracost. if you do not have one , install infracost locally and run  go to https://www.infracost.io/ and download , then run 'infracost register'  to get the key | `string` | `""` | no |
| <a name="input_infracost_repos_json"></a> [infracost\_repos\_json](#input\_infracost\_repos\_json) | this is the JSON config for infracost workflow. it needs to be added as a environment variable to the atlantis container. this is the standard template per project commit but you can customize it if you want to, directions and options are here : https://github.com/infracost/infracost-atlantis | `string` | `"    {\r\n  \"repos\": [\r\n    {\r\n      \"id\": \"/.*/\",\r\n      \"workflow\": \"terraform-infracost\"\r\n    }\r\n  ],\r\n  \"workflows\": {\r\n    \"terraform-infracost\": {\r\n      \"plan\": {\r\n        \"steps\": [\r\n          {\r\n            \"env\": {\r\n              \"name\": \"INFRACOST_OUTPUT\",\r\n              \"command\": \"echo \\\"/tmp/$BASE_REPO_OWNER-$BASE_REPO_NAME-$PULL_NUM-$WORKSPACE-${REPO_REL_DIR//\\\\//-}-infracost.json\\\"\"\r\n            }\r\n          },\r\n          {\r\n            \"env\": {\r\n              \"name\": \"INFRACOST_COMMENT_TAG\",\r\n              \"command\": \"echo \\\"$BASE_REPO_OWNER-$BASE_REPO_NAME-$PULL_NUM-$WORKSPACE-${REPO_REL_DIR//\\\\//-}\\\"\"\r\n            }\r\n          },\r\n          \"init\",\r\n          \"plan\",\r\n          \"show\",\r\n          {\r\n            \"run\": \"infracost breakdown --path=$SHOWFILE \\\\\\n                    --format=json \\\\\\n                    --log-level=info \\\\\\n                    --out-file=$INFRACOST_OUTPUT\\n\"\r\n          },\r\n          {\r\n            \"run\": \"# Choose the commenting behavior, 'new' is a good default:\\n#   new: Create a new cost estimate comment on every run of Atlantis for each project.\\n#   update: Create a single comment and update it. The \\\"quietest\\\" option.\\n#   hide-and-new: Minimize previous comments and create a new one.\\n#   delete-and-new: Delete previous comments and create a new one.\\n# You can use `tag` to customize the hidden markdown tag used to detect comments posted by Infracost. We pass in the project directory here\\n# so that there are no conflicts across projects when posting to the pull request. This is especially important if you\\n# use a comment behavior other than \\\"new\\\".\\ninfracost comment github --repo $BASE_REPO_OWNER/$BASE_REPO_NAME \\\\\\n                        --pull-request $PULL_NUM \\\\\\n                        --path $INFRACOST_OUTPUT \\\\\\n                        --github-token $GITHUB_TOKEN \\\\\\n                        --tag $INFRACOST_COMMENT_TAG \\\\\\n                        --behavior new\\n\"\r\n          },\r\n                    {\r\n            \"run\": \"terraform fmt -check=true -diff=true -write=false\"\r\n          }\r\n        ]\r\n      }\r\n    }\r\n  }\r\n}\r\n"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region you want to deploy atlantis | `string` | `"eastus"` | no |
| <a name="input_ssl_pfx_file"></a> [ssl\_pfx\_file](#input\_ssl\_pfx\_file) | filename for the ssl pfx file.f.f put this in the same folder you are running the module from | `string` | `""` | no |
| <a name="input_ssl_pfx_file_password"></a> [ssl\_pfx\_file\_password](#input\_ssl\_pfx\_file\_password) | filename for the ssl pfx file.f.f put this in the same folder you are running the module from | `string` | `""` | no |
| <a name="input_subscription_name"></a> [subscription\_name](#input\_subscription\_name) | the name of the subscription. This will be used as a prefix for resource group and resource names. | `string` | `""` | no |
| <a name="input_vnet_cidr"></a> [vnet\_cidr](#input\_vnet\_cidr) | The CIDR of the vnet that will be used for the frontend and backend subnets. this cidr will be split in to 2 subnets. it is suggested to use /23 cidr for the vnets and they will be split int two /24 subnets. you could use a smaller cidr like a /28 if you want | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_instance_ip"></a> [container\_instance\_ip](#output\_container\_instance\_ip) | Azure container instance ip |
| <a name="output_waf_public_ip"></a> [waf\_public\_ip](#output\_waf\_public\_ip) | Azure waf public ip |
| <a name="output_waf_whitelisted_ips"></a> [waf\_whitelisted\_ips](#output\_waf\_whitelisted\_ips) | list of waf whitelisted ip cidrs |
<!-- END_TF_DOCS -->