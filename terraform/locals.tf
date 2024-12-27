  locals {
    vpc_id = module.vpc.vpc_id
    public_subnets = module.vpc.public_subnets
    private_subnets = module.vpc.private_subnets
    vpc_name = "koronet-vpc"
    environment = "dev"
    owner = "Koronet"
    cidr_block  = "10.0.0.0/16"
    availability_zones = ["us-east-1a", "us-east-1b"]
    cluster_name           = "koronet-cluster"
    region                 = "us-east-1"
    cluster_version        = "1.31"
    cluster_upgrade_policy = "STANDARD"
    ami_type_AL2023 = "AL2023_x86_64_STANDARD"
    volume_size = 30
    volume_type = "gp3"
    instance_types = [
        "t3a.small",
        "t3.small",
    ]
    min_size     = 1
    max_size     = 5
    desired_size = 1
    azs = slice(data.aws_availability_zones.available.names, 0, 2)
    cluster_ip_family         = "ipv4"
    cluster_service_ipv4_cidr = "10.100.0.0/16"


  }