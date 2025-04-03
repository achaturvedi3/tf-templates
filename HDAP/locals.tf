locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  team_tags = {
    for team in var.application_teams :
    team.name => merge(
      local.common_tags,
      {
        Team        = team.name
        Application = team.application
        Cost_Center = team.cost_center
      }
    )
  }

  network_config = {
    use_existing_vpc     = var.existing_vpc_id != ""
    vpc_id               = var.existing_vpc_id != "" ? var.existing_vpc_id : module.networking.vpc_id
    private_subnet_ids   = length(var.existing_private_subnet_ids) > 0 ? var.existing_private_subnet_ids : module.networking.private_subnets
    availability_zones   = var.availability_zones
    monitoring_role_arn  = var.create_enhanced_monitoring_role ? module.security.monitoring_role_arn : var.existing_monitoring_role_arn
  }

  db_config = {
    parameter_family = "aurora-postgresql14"
    parameters = merge(
      {
        "shared_buffers"      = var.environment == "production" ? "{DBInstanceClassMemory/32768}" : "{DBInstanceClassMemory/65536}"
        "max_connections"     = var.environment == "production" ? "LEAST({DBInstanceClassMemory/9531392},5000)" : "LEAST({DBInstanceClassMemory/9531392},3000)"
        "effective_cache_size" = "{DBInstanceClassMemory/2}"
      },
      var.db_parameters
    )
  }
}