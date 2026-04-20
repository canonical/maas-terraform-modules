# How to configure remote backend state

By default, the examples in this repository use a local backend for Terraform state. This is not recommended for production use, and it is recommended to use a remote backend instead.

This guide details examples of `remote_state` configurations and any additional steps required for using specific remote backends. For more comprehensive explanations of configuration values, see the relevant [Terragrunt](https://docs.terragrunt.com/reference/hcl/blocks/#remote_state) and [Terraform](https://developer.hashicorp.com/terraform/language/backend) documentation. 

## S3 compatible storage

Edit the `remote_state` configuration in `root.hcl` to match the following. Note that for S3 compatible storage, some skip flags are required to prevent Terraform from attempting to validate the endpoint as an actual AWS S3 endpoint:

```hcl
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  // For more details on the S3 backend configuration, see https://developer.hashicorp.com/terraform/language/backend/s3#configuration .
  config = {
    bucket   = "my-state"
    key      = "${path_relative_to_include()}/terraform.tfstate"
    region   = "us-east-1"
    endpoints = {
      s3 = get_env("S3_ENDPOINT_URL")
    }

    // Credentials — set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in your environment.
    access_key = get_env("S3_ACCESS_KEY")
    secret_key = get_env("S3_SECRET_KEY")

    // TLS configuration for connecting to S3 storage via HTTPS.
    custom_ca_bundle = get_env("S3_CA_CHAIN_FILE_PATH")

    // S3 compatible storage options. 
    use_path_style             = true
    skip_credentials_validation  = true
    skip_requesting_account_id   = true
    skip_region_validation       = true
  }
}
```

Populate your environment with the relevant variables/secrets: 

```bash
export S3_ENDPOINT_URL="https://<s3-endpoint-url>"
export S3_ACCESS_KEY="<s3-access-key>"
export S3_SECRET_KEY="<s3-secret-key>"
export S3_CA_CHAIN_FILE_PATH="~/path/to/ca_bundle.crt"
```

Apply your stack. Your state files should be stored in your S3 compatible storage.

## S3 storage on MicroCloud with MicroCeph and RadosGW

When deploying on MicroCloud, it is possible to use RadosGW included with MicroCeph to act as an S3 compatible storage backend for Terraform state. This is recommended over local state files. This section outlines 

#### Prerequisites:
1. You have a running MicroCloud deployment with MicroCeph, and RadosGW is configured and running. 
2. You have the credentials for a RadosGW user.

On one of your MicroCloud nodes, create the following directory and file. Fill out the access key and secret key with the credentials for your RadosGW user: 

```bash
mkdir -p ~/.aws
cat << __EOF > ~/.aws/config
[default]
ca_bundle = /home/ubuntu/deployment/terragrunt-deployment-pipelines/deployments/certs/radosgw.crt
aws_access_key_id = <access-key>
aws_secret_access_key = <secret-key>
__EOF
```

Create a TLS certificate for RadosGW. Specify the relevant IP addresses of your MicroCloud nodes in the `subjectAltName` and `CN` fields: 

```bash
openssl req -x509 -nodes -days 3650 -keyout radosgw.key -subj /CN=<micro1-ip> -addext "subjectAltName=IP:<micro1-ip>, IP:<micro2-ip>, IP:<micro3-ip>" -out radosgw.crt
```

The below example is for a single MicroCloud node:

```shell
root@micro1:~# openssl req -x509 -nodes -days 3650 -keyout radosgw.key \
-subj "/CN=10.1.123.10" \
-addext "subjectAltName=IP:10.1.123.10" \
-out radosgw.crt
...........+....+........+......+.+..............+......+...+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.....+...........+....+..+...+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.............+..+....+......+............+..+.+...+.....+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
.+...+..........+......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*....+.+...+......+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*...+.......................+.......+...........+......+...+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-----
```

Copy the generated `radosgw.crt` file to the bastion or wherever you are running Terragrunt from. 

Populate `root.hcl` with the following: 

```hcl
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  // For more details on the S3 backend configuration, see https://developer.hashicorp.com/terraform/language/backend/s3#configuration .
  config = {
    bucket   = "my-state"
    use_lockfile     = true
    key      = "${path_relative_to_include()}/terraform.tfstate"
    region   = "us-east-1"
    endpoints = {
      s3 = get_env("S3_ENDPOINT_URL")
    }

    // Credentials — set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in your environment.
    access_key = get_env("S3_ACCESS_KEY")
    secret_key = get_env("S3_SECRET_KEY")

    // TLS configuration for connecting to S3 storage via HTTPS.
    custom_ca_bundle = get_env("S3_CA_CHAIN_FILE_PATH")
    
    state_tags = {
      "object:type" : "state"
    }
    lock_tags = {
      "object:type" : "lock"
    }

    use_path_style            = true

    // S3compatible storage options. 
    skip_region_validation             = true
    skip_credentials_validation        = true
    skip_metadata_api_check            = true
    skip_requesting_account_id         = true
    skip_bucket_root_access            = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_enforced_tls           = true

  }
}

// Configure what repositories to search when you run 'terragrunt catalog' in this directory.
catalog {
  urls = [
    "git::https://github.com/canonical/maas-terraform-modules?ref=main",
  ]
}
```

Populate your environment with the relevant variables/secrets: 

```bash
export S3_ENDPOINT_URL="https://<s3-endpoint-url>"      # Endpoint of your MicroCeph node, obtain with `lxc cluster list` on your MicroCloud deployment
export S3_ACCESS_KEY="<radosgw-access-key>"             # RadosGW access key
export S3_SECRET_KEY="<radosgw-secret-key>"             # RadosGW secret key
export S3_CA_CHAIN_FILE_PATH="~/path/to/ca_bundle.crt"  # Path to the TLS certificate you generated for RadosGW and copied to your bastion
```

Apply your stack. Your state files should be stored in your RadosGW S3 storage.
