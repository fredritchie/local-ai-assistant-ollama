resource "aws_db_subnet_group" "chat" {
  name_prefix = "${local.name_prefix}-chat-"
  subnet_ids  = aws_subnet.app[*].id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-chat" })
}

resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-database-"
  description = "PostgreSQL access from application instances only"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-database" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_app" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.app.id
  description                  = "PostgreSQL from Streamlit application instances"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "app_to_database" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.database.id
  description                  = "Persistent PostgreSQL chat storage"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_instance" "chat" {
  identifier_prefix = "${local.name_prefix}-chat-"

  engine                = "postgres"
  engine_version        = "16.6"
  instance_class        = var.database_instance_class
  allocated_storage     = var.database_allocated_storage
  max_allocated_storage = var.database_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = "localai"
  username                    = "localai"
  manage_master_user_password = true
  port                        = 5432
  publicly_accessible         = false
  multi_az                    = var.environment == "prod"
  db_subnet_group_name        = aws_db_subnet_group.chat.name
  vpc_security_group_ids      = [aws_security_group.database.id]

  backup_retention_period         = var.database_backup_retention_days
  copy_tags_to_snapshot           = true
  deletion_protection             = var.enable_deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${local.name_prefix}-chat-final"
  auto_minor_version_upgrade      = true
  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-chat" })
}
