module "network" {
  source = "./network"

  vpc_cidr             = "10.0.0.0/16"
  az_count             = 2
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  cluster_name       = "observability-cluster"
  environment        = "dev"
  enable_nat_gateway = true
}

module "iam" {
  source = "./iam"

  cluster_name = "observability-cluster"
  environment  = "dev"
}

module "eks" {
  source = "./eks"

  cluster_name    = "observability-cluster"
  cluster_version = var.cluster_version

  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_node_role_arn

  private_subnet_ids = values(module.network.private_subnet_ids)

  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  instance_types = ["t3.medium"]

  desired_size = 2
  min_size     = 1
  max_size     = 3

  depends_on = [
    module.network,
    module.iam
  ]
}