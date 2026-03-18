# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  
  config = {
    bucket = "terragrunt-state"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "us-east-1"
    
    endpoints = {
      s3 = "https://10.10.0.26:9000"
    }
    
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    force_path_style            = true
    
    custom_ca_bundle = pathexpand("~/cert.pem")
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

// Configure what repositories to search when you run 'terragrunt catalog' in this directory.
catalog {
  urls = [
    "git::https://github.com/canonical/maas-terraform-modules?ref=main",
  ]
}
