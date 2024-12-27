module "vpc" {
  source = "./modules/aws-vpc"

  name                 = local.vpc_name
  environment          = local.environment
  owner                = local.owner
  cidr                 = local.cidr_block
  private_subnets      = [cidrsubnet(local.cidr_block, 2, 0), cidrsubnet(local.cidr_block, 2, 1)]
  public_subnets       = [cidrsubnet(local.cidr_block, 2, 2), cidrsubnet(local.cidr_block, 2, 3)]
  azs                  = local.availability_zones
  enable_dns_hostnames = true
  enable_nat_gateway   = true
  enable_dns_support   = true
}