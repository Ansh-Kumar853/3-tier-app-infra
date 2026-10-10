resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "PostgreSQL ingress - review source rules before production"
  vpc_id = module.vpc.vpc_id
  ingress { from_port = 5432; to_port = 5432; protocol = "tcp"; security_groups = [module.eks.node_security_group_id] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
  tags = { Project = var.project_name, Environment = var.environment }
}
resource "aws_db_subnet_group" "this" {
  name = "${var.project_name}-${var.environment}-db"
  subnet_ids = module.vpc.database_subnets
}
resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-${var.environment}-postgres"
  engine = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.medium"
  allocated_storage = 30
  max_allocated_storage = 100
  db_name = var.db_name
  username = var.db_username
  password = var.db_password
  port = 5432
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible = false
  storage_encrypted = true
  backup_retention_period = 7
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"
  multi_az = true
}
