# HOW TO USU BACKUP MODULE:

Modify tfvars.tf to set parameters the way it's needed, for example:

environment            = "prod"
kms_key_arn           = "arn:aws:kms:eu-west-1:123456789012:key/abcd1234"
enable_vault_lock     = true
backup_retention_days = 30
tags = {
  Owner       = "cloudfoundation@allianz-trade.com"
  ToBackup    = "true"
  Environment = "prod"
  CostCenter  = "IT-456"
}

# Inicialize 
terraform init

# Plan
terraform plan -var-file="prod.tfvars"

# Apply
terraform apply -var-file="prod.tfvars"


