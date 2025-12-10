# 📋 Overview
This repository contains architectural and technical solutions for three critical AWS security and compliance scenarios, developed in response to regulatory requirements and enterprise best practices.

# 📁 Repository Structure

aws-security-compliance/
├── scenario-1-kms-rotation/
│   ├── architecture-diagrams/
│   ├── implementation-guide.md
│   ├── monitoring-scripts/
│   └── README.md
├── scenario-2-api-security/
│   ├── terraform/
│   ├── cloudformation/
│   ├── security-policies/
│   └── README.md
├── scenario-3-backup-policy/
│   ├── terraform-modules/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── examples/
│   ├── compliance-docs/
│   └── README.md
├── docs/
│   ├── security-assessment.pdf
│   ├── compliance-checklist.md
│   └── architecture-decisions.md
├── scripts/
│   ├── kms-rotation-automation/
│   └── backup-compliance-check/
└── README.md

# 🎯 Solved Scenarios
# 🔐 Scenario 1: KMS Key Rotation with On-Premise HSM

1. Challenges in applying KMS key rotation:

•	Multi-account and multi-service coordination challenges: Each environment (dev, prod, etc.) and each service within that environment (S3, RDS, DynamoDB, etc.) has its own key. This means we have to manage the rotation of many keys without service interruption.
•	Impact of External (BYOK) Keys Generated in On-Premise HSM and Application Across Different Services: The potential impact stems from the interconnections and dependencies between services, in addition to the fact that key segregation can affect different AWS services. Rotation requires generating new keys in the HSM and sending them securely to AWS KMS, which adds operational and security complexity.
•	Key Aliases: AWS services reference aliases, not direct key IDs, but rotation may require updating policies or configurations depending on how it is implemented.
•	Minimize Disruptions: Ensure that rotation does not cause downtime in encrypted services (e.g., RDS, S3, DynamoDB).
•	Regulatory Compliance: Verify that the rotation process complies with the regulator's specific requirements and is auditable.
2. High-level steps to apply rotation

  1.	Inventory and Planning:
    o	Identify all KMS keys (dev-s3, prod-rds, etc.) in the security account.
    o	Define a maintenance window and rotation order (e.g., dev → int → prod).
  2.	Generation of New Keys in HSM:
    o	Create new cryptographic material for each key in the on-premise HSM.
    o	Package and protect the material for shipment to AWS KMS.
  3.	Import to AWS KMS:
    o	Use ImportKeyMaterial in AWS KMS with the new external keys.
    o	Assign the same aliases to the new keys (requires careful handling to avoid conflicts. This way, applications can continue to use the keys even after they have been rotated).
  4.	Configuration Updates:
    o	For S3: Ensure that buckets continue to use the correct alias (usually automatic if an alias is used).
    o	For RDS and DynamoDB: Verify that the KMS keys referenced in the encryption are updated if they use a direct ID (not an alias).
  5.	Testing and Validation:
    o	Verify that new data is encrypted with the new key.
    o	It must be confirmed that existing data remains accessible (non-destructive encryption).
    o	Perform a planned rollback if problems arise.
  6.	Secure Deletion of Old Keys:
    o	Once functionality is confirmed, schedule the deletion of the previous keys after the required grace period.


# How to user backup module:

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





