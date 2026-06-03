resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%^&*-_=+[]{}|:,."
}

# ─── Subnet group ────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-rds"
  subnet_ids = var.db_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-rds-subnet-group" })
}

# ─── Security group ──────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "Security group for ${var.name} RDS MySQL"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-rds-sg" })
}

resource "aws_security_group_rule" "rds_ingress" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = each.value
  description              = "MySQL from ${each.value}"
}

resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "All outbound traffic"
}

# ─── RDS instance ────────────────────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier            = "${var.name}-mysql"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = var.multi_az
  publicly_accessible = false

  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  backup_retention_period    = var.backup_retention_period
  backup_window              = "03:00-04:00"
  maintenance_window         = "mon:04:00-mon:05:00"
  auto_minor_version_upgrade = true

  tags = merge(var.tags, { Name = "${var.name}-mysql" })

  lifecycle {
    ignore_changes = [password]
  }
}

# ─── Secrets Manager ─────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.name}/rds/credentials"
  description             = "RDS MySQL master credentials for ${var.name}"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = tostring(aws_db_instance.this.port)
    dbname   = var.db_name
    engine   = "mysql"
  })
}
