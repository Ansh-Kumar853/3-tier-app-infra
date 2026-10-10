resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Allow PostgreSQL only from EKS worker nodes"
  vpc_id = module.vpc.vpc_id
  ingress {
    description = "PostgreSQL from EKS nodes"
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Project = var.project_name, Environment = var.environment }
}
resource "aws_db_subnet_group" "this" {
  name = "${var.project_name}-${var.environment}-db"
  subnet_ids = module.vpc.database_subnets
  tags = { Project = var.project_name, Environment = var.environment }
}
resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-${var.environment}-postgres"
  engine = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.medium"
  allocated_storage = 30
  max_allocated_storage = 100
  storage_type = "gp3"
  db_name = var.db_name
  username = var.db_username
  password = var.db_password
  port = 5432
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible = false
  storage_encrypted = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  backup_retention_period = 7
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"
  multi_az = true
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot = true
  tags = { Project = var.project_name, Environment = var.environment }
}
