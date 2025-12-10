# 📋 Overview
This repository contains architectural and technical solutions for three critical AWS security and compliance scenarios, developed in response to regulatory requirements and enterprise best practices.

# 🎯 Solved Scenarios
## 🔐 SCENARIO 1: KMS Key Rotation with On-Premise HSM

### 1. Challenges in Applying KMS Key Rotation

- **Multi-account and multi-service coordination challenges**: Each environment (dev, prod...) and service within that environment (S3, RDS, DynamoDB...) has its own key. This means we have to manage the rotation of many keys without service interruption.

- **Impact of External (BYOK) Keys Generated in On-Premise HSM and Application Across Different Services**: The potential impact stems from the interconnections and dependencies between services, in addition to the fact that key segregation can affect different AWS services. Rotation requires generating new keys in the HSM and sending them securely to AWS KMS, which adds operational and security complexity.

- **Key Aliases**: AWS services reference aliases, not direct key IDs, but rotation may require updating policies or configurations depending on how it is implemented.

- **Minimize Disruptions**: Ensure that rotation does not cause downtime in encrypted services (e.g., RDS, S3, DynamoDB).

- **Regulatory Compliance**: Verify that the rotation process complies with the regulator's specific requirements and is auditable.

### 2. High-Level Steps to Apply Rotation

1. **Inventory and Planning:**
   - Identify all KMS keys (dev-s3, prod-rds, etc.) in the security account.
   - Define a maintenance window and rotation order (e.g., dev → int → prod).

2. **Generation of New Keys in HSM:**
   - Create new cryptographic material for each key in the on-premise HSM.
   - Package and protect the material for shipment to AWS KMS.

3. **Import to AWS KMS:**
   - Use `ImportKeyMaterial` in AWS KMS with the new external keys.
   - Assign the same aliases to the new keys (requires careful handling to avoid conflicts. This way, applications can continue to use the keys even after they have been rotated).

4. **Configuration Updates:**
   - For S3: Ensure that buckets continue to use the correct alias (usually automatic if an alias is used).
   - For RDS and DynamoDB: Verify that the KMS keys referenced in the encryption are updated if they use a direct ID (not an alias).

5. **Testing and Validation:**
   - Verify that new data is encrypted with the new key.
   - It must be confirmed that existing data remains accessible (non-destructive encryption).
   - Perform a planned rollback if problems arise.

6. **Secure Deletion of Old Keys:**
   - Once functionality is confirmed, schedule the deletion of the previous keys after the required grace period.

### 3. Monitoring Resources Without Rotation Applied

Use AWS Config with custom or managed rules:

- **AWS Config Rules:**
  - `kms-key-not-rotated`: Predefined rule to detect KMS keys not rotated within the defined period.
  - Create custom rules to validate that RDS, DynamoDB, and S3 use the correct key version.

- **AWS Security Hub:**
  - Integrate findings from AWS Config and enable security controls related to KMS (e.g., [KMS.1]).

- **Amazon EventBridge + AWS Lambda:**
  - Automate detection and notification when a resource uses an old key.

- **Key Tagging:**
  - Tag keys with a rotation date and use AWS Resource Groups to inventory resources by key.

### 4. Protecting Key Material During Transport from HSM to KMS

The best practice is to follow the AWS KMS BYOK (Bring Your Own Key) process:

1. **Generate Key Package in HSM:**
   - Create a symmetric key in the HSM.
   - Use `get-public-key` from the KMS exchange key (obtained via `GetParametersForImport`).

2. **Encryption of Key Material:**
   - Encrypt the symmetric key with the KMS public key **inside the HSM (never export unencrypted material).**

3. **Secure Transport:**
   - Transmit the encrypted material via TLS/SSL connections (AWS KMS API/SDK).
   - Use AWS CloudHSM or an HSM connected via AWS Direct Connect/VPN to reduce internet exposure.

4. **Import Process:**
   - Call `ImportKeyMaterial` with the import token and the encrypted material.
   - AWS KMS decrypts it internally using its private key.

5. **Secure Deletion of Intermediate Material:**
   - Delete plain key material from the HSM and any traces in logs after import.

**Additional Recommendation:**
Consider using AWS CloudHSM integrated with KMS to simplify BYOK management and rotation, reducing the complexity of manual transport.

---

