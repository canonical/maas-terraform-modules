resource "terraform_data" "bootstrap_juju" {
  input = {
    cloud_name     = var.cloud_name
    lxd_project    = var.lxd_project
    model_defaults = var.model_defaults
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju show-controller ${self.input.cloud_name}-default >/dev/null 2>&1 && exit 0

      cat >clouds.yaml <<EOL
      ${local.clouds_file}
      EOL

      cat >credentials.yaml <<EOL
      ${local.credentials_file}
      EOL

      juju add-cloud --client ${self.input.cloud_name} -f clouds.yaml
      juju add-credential ${self.input.cloud_name} -f credentials.yaml --client
      juju bootstrap ${self.input.cloud_name} --config project=${self.input.lxd_project} ${local.model_defaults_args}
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju destroy-controller ${self.input.cloud_name}-default --destroy-all-models --force --no-prompt
      juju remove-cloud ${self.input.cloud_name} --client
    EOT
    when    = destroy
  }
}

locals {
  clouds_file = templatefile("${path.module}/templates/clouds.yaml.tftpl", {
    lxd_address = var.lxd_address,
    cloud_name  = var.cloud_name,
  })
  credentials_file = templatefile("${path.module}/templates/credentials.yaml.tftpl", {
    lxd_trust_token = var.lxd_trust_token,
    cloud_name      = var.cloud_name,
  })
  
  model_defaults_args = join(" ", [
    for key, value in var.model_defaults : "--model-default ${key}=${value}"
  ])
}
