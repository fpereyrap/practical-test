# terraform-aws-vpc


```h
module "vpc" {
  source = "../terraform-modules/terraform-aws-vpc"

  name                 = var.name
  environment          = var.environment
  owner                = var.owner
  cidr                 = var.cidr_block
  private_subnets      = [cidrsubnet(var.cidr_block, 2, 0), cidrsubnet(var.cidr_block, 2, 1)]
  public_subnets       = [cidrsubnet(var.cidr_block, 2, 2), cidrsubnet(var.cidr_block, 2, 3)]
  azs                  = var.availability_zones
  enable_dns_hostnames = true
  enable_nat_gateway   = false
  enable_dns_support   = true
  tags                 = local.default_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| attributes | Additional attributes (e.g. `1`) | list | `<list>` | no |
| cidr_block | CIDR for the VPC | string | - | yes |
| delimiter | Delimiter to be used between `namespace`, `stage`, `name` and `attributes` | string | `-` | no |
| enable_classiclink | A boolean flag to enable/disable ClassicLink for the VPC | string | `false` | no |
| enable_classiclink_dns_support | A boolean flag to enable/disable ClassicLink DNS Support for the VPC | string | `false` | no |
| enable_dns_hostnames | A boolean flag to enable/disable DNS hostnames in the VPC | string | `true` | no |
| enable_dns_support | A boolean flag to enable/disable DNS support in the VPC | string | `true` | no |
| instance_tenancy | A tenancy option for instances launched into the VPC | string | `default` | no |
| name | Name  (e.g. `app` or `cluster`) | string | - | yes |
| owner | Owner  (e.g. `Infrastructure and Security`) | string | - | yes |
| environment | Environment (e.g. `prod`, `dev`, `staging`) | string | - | yes |
| tags | Additional tags (e.g. map(`BusinessUnit`,`XYZ`) | map | `<map>` | no |
| create_vpc | Controls if VPC should be created | string | true | no
| cidr | The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden string | `0.0.0.0/0` | yes |
| assign_generated_ipv6_cidr_block | Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC | string | `false` | no |
| secondary_cidr_blocks | List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool | list | `[]` | no |
| enable_api_gateway_endpoint | Should be true if you want to provision an apigateway endpoint to the VPC | bool | `false` | no |
| enable_ssm_endpoint | Should be true if you want to provision an ssm endpoint to the VPC | bool | `false` | no |
| enable_s3_endpoint | Should be true if you want to provision an S3 endpoint to the VPC | bool | `false` | no |
| enable_ec2_endpoint | Should be true if you want to provision an EC2 endpoint to the VPC | bool | `false` | no |
| vpc_endpoint_api_gateway_tags | Additional tags for the VPC api gateway endpoint | map | `{}` | no |


## Outputs

| Name | Description |
|------|-------------|
| igw_id | The ID of the Internet Gateway |
| ipv6_cidr_block | The IPv6 CIDR block |
| vpc_cidr_block | The CIDR block of the VPC |
| vpc_default_network_acl_id | The ID of the network ACL created by default on VPC creation |
| vpc_default_route_table_id | The ID of the route table created by default on VPC creation |
| vpc_default_security_group_id | The ID of the security group created by default on VPC creation |
| vpc_id | The ID of the VPC |
| vpc_ipv6_association_id | The association ID for the IPv6 CIDR block |
| vpc_main_route_table_id | The ID of the main route table associated with this VPC. |
