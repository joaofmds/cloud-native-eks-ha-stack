# Terraform Stack

This directory contains reusable Terraform modules and environment definitions for deploying the EKS high availability stack. The layout is organised as follows:

- `vpc/`, `eks/`, `route53/`, `s3-loki/`, `iam/`: composable modules that provision the core networking, compute and IAM layers. Each module exposes a `variables.tf` and `outputs.tf` for integration.
- `envs/<name>/`: top-level configurations for individual environments. Each environment wires the modules together, configures the remote backend and defines input variables.
- `providers.tf`: shared Terraform and AWS provider requirements that are reused by every environment through a symbolic link.

## Remote state backends

Environment configurations use an Amazon S3 backend with DynamoDB table locking. The development stack is configured in `envs/dev/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "cloud-native-eks-ha-stack-dev-tfstate"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloud-native-eks-ha-stack-terraform-locks"
    encrypt        = true
  }
}
```

Create the S3 bucket and DynamoDB table before running `terraform init`. For future environments copy the `envs/dev` directory, adjust the backend parameters and customise the variable defaults.

## Usage

All commands should be executed from an environment directory (for example `infra/terraform/envs/dev`). The examples below assume AWS credentials are already available in your shell via environment variables, `~/.aws/credentials` or another supported mechanism.

1. Format the configuration:
   ```bash
   terraform fmt
   ```
2. Initialise the working directory (use `-backend=false` if the remote backend resources are not created yet):
   ```bash
   terraform init
   # or
   terraform init -backend=false
   ```
3. Review the execution plan, optionally supplying a TFVARS file with sensitive overrides:
   ```bash
   terraform plan -var-file="dev.auto.tfvars"
   ```
4. Apply the changes once the plan looks correct:
   ```bash
   terraform apply -var-file="dev.auto.tfvars"
   ```

### Managing variables and secrets

The development environment ships with opinionated defaults stored in `variables.tf`. Provide overrides by creating a `.tfvars` file or exporting environment variables that follow the `TF_VAR_` naming convention. Sensitive values such as KMS key ARNs, IAM principal ARNs or Route53 zone IDs should **not** be committed to version control—store them in encrypted state, environment variables or secrets management tooling instead.

### Additional notes

- Provider version and Terraform constraints are managed centrally in `providers.tf`. Link this file into any new environment directory to maintain a consistent toolchain.
- Module outputs in each environment (`outputs.tf`) expose key artefacts (VPC IDs, cluster names, IAM role ARNs, etc.) that can be consumed by downstream automation.
- Run `terraform validate` after `terraform init` to ensure configuration integrity.
