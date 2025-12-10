# outputs.tf
output "module_summary" {
  value = {
    backup_vault_name     = aws_backup_vault.central_vault.name
    backup_plan_name      = aws_backup_plan.backup_plan.name
    vault_lock_enabled    = var.enable_vault_lock
    kms_encryption_key    = var.kms_key_arn
    retention_days        = var.backup_retention_days
    cold_storage_days     = var.cold_storage_retention_days
    selection_criteria    = "ToBackup=true, Environment=${var.environment}, Owner=${var.tags["Owner"]}"
    supported_resources   = var.supported_resources
  }
  description = "Resumen de la configuración del módulo de Backup"
}