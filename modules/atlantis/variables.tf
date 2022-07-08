
variable "location" {
  type        = string
  default     = "eastus"
  description = "Azure region you want to deploy atlantis"
}

variable "create_and_attach_storage" {
  type        = bool
  default     = true
  description = "if you do not weant blob stoage created and mapped to the container change this to false"
}

variable "subscription_name" {
  type        = string
  default     = ""
  description = "the name of the subscription"
}

variable "vnet_cidr" {
  type        = string
  default     = ""
  description = "The CIDR of the vnet that will be used for the frontend and backend subnets. this cidr will be split in to 2 subnets. it is suggested to use /23 cidr for the vnets and they will be split int two /24 subnets. you could use a smaller cidr like a /28 if you want"
}


variable "atlantis_gh_user" {
  default     = ""
  sensitive   = true
  description = "The github user to use for the access to the github repo"
}

variable "atlantis_gh_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "The github token to use for the access to the github repo"

}
variable "atlantis_gh_webhook_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "The github webhook to use for the access to the github"
}

variable "atlanits_repo_whitelist" {
  type        = string
  default     = ""
  sensitive   = true
  description = "the address for the github repo. do not include http://. just 'github.com/org/repo' is needed "
}

variable "az_subscription_id" {
  type        = string
  default     = ""
  description = "the subscription ID for Azure"
}

variable "az_tenant_id" {
  type        = string
  default     = ""
  description = "the tenant_id for azure subscription"
}

variable "atlantis_whitelist_ips" {
  type        = list(string)
  default     = [""]
  description = "We are protecting Atlantis with a WAFv2 App gateway. Git webhook IP's are being automatically added to the WAFv2 policy. Here you should include any public IP CIDR's you want to access the atlantis UI with . I.E. Home connection, Datacenters, offices, etc."
}

##  for SSL config not setup yet

variable "enable_ssl" {
  type        = bool
  default     = false
  description = "if you answer true this will enable SSL config for atlantis and the WAFv2. you will need pfx, pem and crt files. you can create your own self signed for testing but besure to disable SSL verification on github webhook"
}

variable "ssl_pfx_file" {
  type        = string
  default     = ""
  description = "filename fdor the ssl pfx file.f.f put this in the same folder you are running the module from"
}

variable "ssl_pfx_file_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "filename fdor the ssl pfx file.f.f put this in the same folder you are running the module from"
}

variable "atlantis_ui_basic_auth" {
  type        = bool
  default     = false
  description = "if you answer true this will enable a user/pass defined in atlantis_ui_user and atlantis_ui_pass variables as a basic auth to the atlantis UI. However right now this feature seems to be broken on current docker images. don't enabnle this until it's fixed"

}


variable "atlantis_ui_user" {
  type        = string
  default     = ""
  description = "the user name to use in the atlantis_ui_user auth"
}

variable "atlantis_ui_pass" {
  type        = string
  default     = ""
  sensitive   = true
  description = "the password to use in the atlantis_ui_pass auth"
}


variable "infracost_api_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "the api key from infracost. if you do not have one , install infracost locally and run  go to https://www.infracost.io/ and download , then run 'infracost register'  to get the key"
}


variable "infracost_repos_json" {
  type        = string
  default     = <<CONFIG
    {
  "repos": [
    {
      "id": "/.*/",
      "workflow": "terraform-infracost"
    }
  ],
  "workflows": {
    "terraform-infracost": {
      "plan": {
        "steps": [
          {
            "env": {
              "name": "INFRACOST_OUTPUT",
              "command": "echo \"/tmp/$BASE_REPO_OWNER-$BASE_REPO_NAME-$PULL_NUM-$WORKSPACE-$${REPO_REL_DIR//\\//-}-infracost.json\""
            }
          },
          {
            "env": {
              "name": "INFRACOST_COMMENT_TAG",
              "command": "echo \"$BASE_REPO_OWNER-$BASE_REPO_NAME-$PULL_NUM-$WORKSPACE-$${REPO_REL_DIR//\\//-}\""
            }
          },
          "init",
          "plan",
          "show",
          {
            "run": "infracost breakdown --path=$SHOWFILE \\\n                    --format=json \\\n                    --log-level=info \\\n                    --out-file=$INFRACOST_OUTPUT\n"
          },
          {
            "run": "# Choose the commenting behavior, 'new' is a good default:\n#   new: Create a new cost estimate comment on every run of Atlantis for each project.\n#   update: Create a single comment and update it. The \"quietest\" option.\n#   hide-and-new: Minimize previous comments and create a new one.\n#   delete-and-new: Delete previous comments and create a new one.\n# You can use `tag` to customize the hidden markdown tag used to detect comments posted by Infracost. We pass in the project directory here\n# so that there are no conflicts across projects when posting to the pull request. This is especially important if you\n# use a comment behavior other than \"new\".\ninfracost comment github --repo $BASE_REPO_OWNER/$BASE_REPO_NAME \\\n                        --pull-request $PULL_NUM \\\n                        --path $INFRACOST_OUTPUT \\\n                        --github-token $GITHUB_TOKEN \\\n                        --tag $INFRACOST_COMMENT_TAG \\\n                        --behavior new\n"
          }
        ]
      }
    }
  }
}
CONFIG
  sensitive   = true
  description = "this is the JSON config for infracost workflow. it needs to be added as a enviorment variable to the atlantis container. this is the standard template per project commit but you can customize it if you want to, directions and options are here : https://github.com/infracost/infracost-atlantis"
}

