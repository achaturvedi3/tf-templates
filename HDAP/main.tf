module "security" {
  source = "./modules/security"

  name = "${var.project_name}-${var.environment}"
  create_monitoring_role = var.create_enhanced_monitoring_role
  
  tags = local.common_tags
}

module "aurora_shared" {
  source = "./modules/aurora_postgresql"
  count  = var.create_shared_aurora ? 1 : 0

  name        = "${var.project_name}-shared-${var.environment}"
  engine      = "aurora-postgresql"
  engine_version = var.db_engine_version
  
  vpc_id      = local.network_config.vpc_id
  subnet_ids  = local.network_config.private_subnet_ids
  
  instance_class = var.db_instance_class
  instances = {
    1 = {}
    2 = {}
  }
  
  monitoring_role_arn = local.network_config.monitoring_role_arn
  
  deletion_protection = var.db_deletion_protection
  
  parameter_group_family = local.db_config.parameter_family
  parameter_group_parameters = local.db_config.parameters
  
  security_group_id = module.networking.db_security_group_id
  
  tags = local.common_tags
}

module "aurora_app" {
  source = "./modules/aurora_postgresql"
  
  for_each = { for team in var.application_teams : team.name => team }
  
  name        = "${var.project_name}-${each.key}-${var.environment}"
  engine      = "aurora-postgresql"
  engine_version = var.db_engine_version
  
  vpc_id      = local.network_config.vpc_id
  subnet_ids  = local.network_config.private_subnet_ids
  
  instance_class = each.value.instance_class != "" ? each.value.instance_class : var.db_instance_class
  
  instances = {
    for i in range(1, each.value.instance_count + 1) : i => {}
  }
  
  database_name = each.value.db_name
  
  monitoring_role_arn = local.network_config.monitoring_role_arn
  
  deletion_protection = var.db_deletion_protection
  
  parameter_group_family = local.db_config.parameter_family
  parameter_group_parameters = merge(local.db_config.parameters, each.value.parameters)
  
  security_group_id = module.networking.db_security_group_id
  
  tags = local.team_tags[each.key]
}