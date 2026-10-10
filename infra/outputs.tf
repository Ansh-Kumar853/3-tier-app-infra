output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "region" { value = var.aws_region }
output "backend_ecr_url" { value = aws_ecr_repository.backend.repository_url }
output "frontend_ecr_url" { value = aws_ecr_repository.frontend.repository_url }
output "vpc_id" { value = module.vpc.vpc_id }
