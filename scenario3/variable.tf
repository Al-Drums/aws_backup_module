# variables.tf
variable "region" {
  description = "region name (e.g., prod, dev)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, dev)"
  type        = string
}

variable "backup_plan_name" {
  description = "Name of the backup plan"
  type        = string
  default     = "central-backup-plan"
}

variable "backup_vault_name" {
  description = "Name of the backup vault"
  type        = string
  default     = "central-backup-vault"
}

variable "backup_frequency" {
  description = "Backup frequency in hours"
  type        = number
  default     = 24
}

variable "backup_retention_days" {
  description = "Retention period in days"
  type        = number
  default     = 30
}

variable "cold_storage_retention_days" {
  description = "Cold storage retention period in days"
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "enable_vault_lock" {
  description = "Enable WORM protection via Vault Lock"
  type        = bool
  default     = true
}

variable "vault_lock_min_retention_days" {
  description = "Minimum retention days for Vault Lock"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "supported_resources" {
  description = "List of AWS resource types to backup"
  type        = list(string)
  default = [
    "EC2",
    "EBS",
    "RDS",
    "DynamoDB",
    "EFS",
    "FSx",
    "Storage Gateway",
    "DocumentDB"
  ]
}
