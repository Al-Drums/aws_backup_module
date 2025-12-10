# Ejemplo de uso (example/main.tf)
module "backup_prod" {
  source = "../modules/backup"

  environment            = "prod"
  backup_plan_name      = "prod-backup-plan"
  backup_vault_name     = "prod-backup-vault"
  backup_retention_days = 30
  cold_storage_retention_days = 90
  kms_key_arn          = "arn:aws:kms:eu-west-1:123456789012:key/abcd1234-5678-90ef-ghij-klmnopqrstuv"
  enable_vault_lock    = true
  vault_lock_min_retention_days = 7
  
  tags = {
    Owner       = "cloudfoundation@allianz-trade.com"
    ToBackup    = "true"
    Environment = "prod"
    Service     = "Backup"
    CostCenter  = "IT-123"
  }

  supported_resources = [
    "EC2",
    "EBS",
    "RDS",
    "DynamoDB",
    "EFS",
    "FSx",
    "Storage Gateway",
    "DocumentDB",
    "Neptune"
  ]
}

module "backup_dev" {
  source = "../modules/backup"

  environment            = "dev"
  backup_retention_days = 7  # Menos retención para dev
  cold_storage_retention_days = 0  # Sin cold storage para dev
  kms_key_arn          = "arn:aws:kms:eu-west-1:123456789012:key/abcd1234-5678-90ef-ghij-klmnopqrstuv"
  enable_vault_lock    = false  # Sin WORM para dev
  
  tags = {
    Owner       = "cloudfoundation@allianz-trade.com"
    ToBackup    = "true"
    Environment = "dev"
    Service     = "Backup"
    CostCenter  = "IT-123"
  }
}
