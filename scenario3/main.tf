# main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# 1. Crear Backup Vault con encriptación KMS
resource "aws_backup_vault" "central_vault" {
  name        = "${var.backup_vault_name}-${var.environment}"
  kms_key_arn = var.kms_key_arn
  tags        = merge(var.tags, {
    Environment = var.environment
    Owner       = "cloudfoundation@allianz-trade.com"
    ToBackup    = "true"
  })
}

# 2. Configurar Vault Lock para protección WORM (si está habilitado)
resource "aws_backup_vault_lock_configuration" "vault_lock" {
  count = var.enable_vault_lock ? 1 : 0

  backup_vault_name   = aws_backup_vault.central_vault.name
  changeable_for_days = var.vault_lock_min_retention_days
  max_retention_days  = 36500  # ~100 años
  min_retention_days  = var.vault_lock_min_retention_days
}

# 3. Crear Backup Plan con frecuencia y retención
resource "aws_backup_plan" "backup_plan" {
  name = "${var.backup_plan_name}-${var.environment}"

  rule {
    rule_name         = "${var.environment}-daily-backup"
    target_vault_name = aws_backup_vault.central_vault.name
    schedule          = "cron(0 2 ? * * *)"  # Diario a las 2 AM UTC

    lifecycle {
      cold_storage_after = var.cold_storage_retention_days
      delete_after       = var.backup_retention_days + var.cold_storage_retention_days
    }

    # Configurar encriptación con KMS
    copy_action {
      destination_vault_arn = aws_backup_vault.central_vault.arn
      
      lifecycle {
        cold_storage_after = var.cold_storage_retention_days
        delete_after       = var.backup_retention_days + var.cold_storage_retention_days
      }
    }
  }

  # Etiquetas avanzadas para organización
  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "enabled"  # Para consistencia en Windows
    }
    resource_type = "EC2"
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Owner       = "cloudfoundation@allianz-trade.com"
    ManagedBy   = "Terraform"
  })
}

# 4. Crear selección de recursos basada en tags
resource "aws_backup_selection" "resource_selection" {
  name         = "${var.environment}-auto-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  plan_id      = aws_backup_plan.backup_plan.id

  # Seleccionar recursos con tags específicos
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "ToBackup"
    value = "true"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = var.environment
  }

  # También podemos seleccionar por tipo de recurso
  resources = []

  # Condición para múltiples tags (AND lógico)
  condition {
    string_equals {
      key   = "Owner"
      value = var.tags["Owner"]
    }
  }

  condition {
    string_like {
      key   = "Service"
      value = "*"  # Todos los servicios
    }
  }
}

# 5. IAM Role para AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "AWSBackupRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Política personalizada para operaciones específicas
resource "aws_iam_policy" "backup_custom_policy" {
  name        = "BackupCustomPolicy-${var.environment}"
  description = "Política personalizada para AWS Backup"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [var.kms_key_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "rds:DescribeDBInstances",
          "dynamodb:ListTables",
          "efs:DescribeFileSystems"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "custom_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = aws_iam_policy.backup_custom_policy.arn
}

# 6. Notificaciones de Backup (opcional)
resource "aws_backup_vault_notifications" "backup_notifications" {
  backup_vault_name   = aws_backup_vault.central_vault.name
  sns_topic_arn       = aws_sns_topic.backup_notifications.arn
  backup_vault_events = ["BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "RESTORE_JOB_COMPLETED", "COPY_JOB_FAILED"]
}

resource "aws_sns_topic" "backup_notifications" {
  name = "backup-notifications-${var.environment}"
  
  tags = var.tags
}

# 7. Reportes de Backup (opcional)
resource "aws_backup_report_plan" "backup_reports" {
  name        = "${var.environment}-backup-report"
  description = "Reportes de cumplimiento de backup"

  report_delivery_channel {
    formats = ["CSV", "JSON"]
    s3_bucket_name = aws_s3_bucket.backup_reports.bucket
  }

  report_setting {
    report_template = "BACKUP_JOB_REPORT"
    
    # Incluir todos los recursos
    accounts = ["*"]
    regions  = ["*"]
    
    # Filtrar por tags
    framework_arns = []
    organization_units = []
  }

  tags = var.tags
}

resource "aws_s3_bucket" "backup_reports" {
  bucket = "backup-reports-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  tags = var.tags
}

data "aws_caller_identity" "current" {}

# 8. Módulo de Outputs
output "backup_vault_arn" {
  value       = aws_backup_vault.central_vault.arn
  description = "ARN del Backup Vault"
}

output "backup_plan_id" {
  value       = aws_backup_plan.backup_plan.id
  description = "ID del Backup Plan"
}

output "backup_role_arn" {
  value       = aws_iam_role.backup_role.arn
  description = "ARN del IAM Role para Backup"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.backup_notifications.arn
  description = "ARN del SNS Topic para notificaciones"
}
