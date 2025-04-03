locals {
  name = "${var.name}-aurora-pg"
  port = var.port
  use_az_data = length(var.availability_zones) == 0
  master_password = var.master_password == "" ? random_password.master_password[0].result : var.master_password
  is_serverless_v2 = can(regex("serverless", var.instance_class))
  
  default_tags = {
    Name        = local.name
    Environment = var.environment
    Application = var.application_name
    Terraform   = "true"
  }
  
  tags = merge(local.default_tags, var.tags)
  
  create_monitoring_role = var.monitoring_interval > 0 && var.monitoring_role_arn == null
}

resource "random_password" "master_password" {
  count = var.master_password == "" ? 1 : 0
  
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

data "aws_availability_zones" "available" {
  count = local.use_az_data ? 1 : 0
  state = "available"
}

resource "aws_db_subnet_group" "this" {
  name        = "${local.name}-subnet-group"
  description = "Subnet group for ${local.name} Aurora PostgreSQL cluster"
  subnet_ids  = var.subnet_ids
  
  tags = local.tags
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${local.name}-cluster-pg"
  description = "Cluster parameter group for ${local.name} Aurora PostgreSQL"
  family      = var.db_parameter_group_family
  
  dynamic "parameter" {
    for_each = var.cluster_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }
  
  tags = local.tags
}

resource "aws_db_parameter_group" "this" {
  name        = "${local.name}-instance-pg"
  description = "Instance parameter group for ${local.name} Aurora PostgreSQL"
  family      = var.db_parameter_group_family
  
  dynamic "parameter" {
    for_each = var.instance_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }
  
  tags = local.tags
}

resource "aws_rds_cluster" "this" {
  cluster_identifier          = local.name
  engine                      = "aurora-postgresql"
  engine_version              = var.engine_version
  availability_zones          = local.use_az_data ? data.aws_availability_zones.available[0].names : var.availability_zones
  database_name               = var.database_name
  master_username             = var.master_username
  master_password             = local.master_password
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = var.security_group_ids
  
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  
  backtrack_window = var.backtrack_window
  
  port                                = local.port
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.this.name
  storage_encrypted                   = var.storage_encrypted
  kms_key_id                          = var.kms_key_id
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = "${local.name}-final-snapshot-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  apply_immediately                   = var.apply_immediately
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  
  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.is_serverless_v2 ? [1] : []
    content {
      min_capacity = var.serverless_min_capacity
      max_capacity = var.serverless_max_capacity
    }
  }
  
  allow_major_version_upgrade = var.allow_major_version_upgrade
  
  tags = local.tags
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count
  
  identifier              = "${local.name}-instance-${count.index + 1}"
  cluster_identifier      = aws_rds_cluster.this.id
  engine                  = aws_rds_cluster.this.engine
  engine_version          = aws_rds_cluster.this.engine_version
  instance_class          = var.instance_class
  db_subnet_group_name    = aws_db_subnet_group.this.name
  db_parameter_group_name = aws_db_parameter_group.this.name
  
  publicly_accessible       = var.publicly_accessible
  
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn
  
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id
  performance_insights_retention_period = var.performance_insights_retention_period
  
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.name}-high-cpu-utilization"
  alarm_description   = "This alarm monitors ${local.name} Aurora PostgreSQL cluster CPU utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_utilization_threshold
  
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
  
  alarm_actions = var.cloudwatch_alarm_actions
  ok_actions    = var.cloudwatch_ok_actions
  
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "freeable_memory" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.name}-low-freeable-memory"
  alarm_description   = "This alarm monitors ${local.name} Aurora PostgreSQL cluster freeable memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.freeable_memory_threshold
  
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
  
  alarm_actions = var.cloudwatch_alarm_actions
  ok_actions    = var.cloudwatch_ok_actions
  
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "disk_queue_depth" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.name}-high-disk-queue-depth"
  alarm_description   = "This alarm monitors ${local.name} Aurora PostgreSQL cluster disk queue depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.disk_queue_depth_threshold
  
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
  
  alarm_actions = var.cloudwatch_alarm_actions
  ok_actions    = var.cloudwatch_ok_actions
  
  tags = local.tags
}

resource "aws_rds_cluster_endpoint" "reader" {
  count = var.create_custom_endpoints ? 1 : 0
  
  cluster_identifier          = aws_rds_cluster.this.id
  cluster_endpoint_identifier = "${local.name}-reader"
  custom_endpoint_type        = "READER"
  
  excluded_members = []
  
  tags = local.tags
}