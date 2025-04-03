aws_region  = "us-east-1"
environment = "test"
project_name = "hdap-aurora"
owner       = "VBCAPPSDEVOPS"

existing_vpc_id = "vpc-0123456789abcdef0"
existing_private_subnet_ids = [
  "subnet-0123456789abcdef1", 
  "subnet-0123456789abcdef2",
  "subnet-0123456789abcdef3"
]
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

db_instance_class = "db.r5.large"
db_engine_version = "14.6"
db_deletion_protection = true

db_parameters = {
  "log_statement" = "all"
  "log_min_duration_statement" = "1000"
  "shared_preload_libraries" = "pg_stat_statements"
  "pg_stat_statements.track" = "all"
}

application_teams = [
  {
    name = "hdap"
    application = "hdap"
    cost_center = "some-cost-center"
    db_name = "hdap-postgres_db"
    instance_count = 2
    instance_class = "db.r5.xlarge"
    parameters = {
      "work_mem" = "16MB"
      "maintenance_work_mem" = "1GB"
    }
  },
  {
    name = "vbc"
    application = "vbc"
    cost_center = "business-intelligence"
    db_name = "reporting_db"
    instance_count = 2
  }
]