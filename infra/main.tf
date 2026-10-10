data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  name = "${var.project_name}-${var.environment}"
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Project = var.project_name
    Environment = var.environment
    ManagedBy = "Terraform"
  }
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"
  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs
  private_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets   = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 4)]
  database_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]
  enable_nat_gateway = true
  single_nat_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true
  create_database_subnet_group = false
  public_subnet_tags = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${local.name}" = "shared"
  }
  tags = local.tags
}
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"
  cluster_name = local.name
  cluster_version = var.kubernetes_version
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = length(var.eks_public_access_cidrs) > 0 ? var.eks_public_access_cidrs : ["127.0.0.1/32"]
  cluster_endpoint_private_access = true
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  enable_irsa = true
  eks_managed_node_groups = {
    default = {
      instance_types = var.eks_node_instance_types
      min_size = 2
      max_size = var.max_nodes
      desired_size = var.desired_nodes
      capacity_type = "ON_DEMAND"
    }
  }
  tags = local.tags
}
resource "aws_ecr_repository" "backend" {
  name = "${local.name}/backend"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = local.tags
}
resource "aws_ecr_repository" "frontend" {
  name = "${local.name}/frontend"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = local.tags
}
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({ rules = [{ rulePriority = 1, description = "Keep last 30 tagged images", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }, action = { type = "expire" } }] })
}
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({ rules = [{ rulePriority = 1, description = "Keep last 30 tagged images", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }, action = { type = "expire" } }] })
}
