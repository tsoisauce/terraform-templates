# Terraform Templates

Terraform allows for Infrastructure as code in a delcarative manner. It is very useful in consolidating and standardizing resource configurations. This is a repository to help bootstrap your project with infrastructure.

NOTE: never use `terraform destory` it will destory your whole infrastructure. Remove the proper resource and run `terraform plan` and `terraform apply` or you can target a specific resource for removal `terraform <apply_or_destroy> -target <resource_name>`

## Commands

### `terraform init`

initalizes the project and downloads all necessary pluggins based on resource and providers stated.

### `terraform plan`

shows detail information about your terraform config settings

### `terraform apply`

apply changes

### `terraform state list`

this command lists out all providers and resources attributes.# terraform-templates
