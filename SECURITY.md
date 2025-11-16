# Security Operations Guide

This document captures the procedures we follow for managing shared secrets, personally identifiable information (PII), and audit logs across the ShiftLink Amplify environment.

## 1. Secret Rotation — `SITE_KEY_HMAC_SECRET`

### Location
- AWS Secrets Manager  
- Secret name: `SITE_KEY_HMAC_SECRET`  
- Created in stack `amplify-shiftlinkmainxcodeproj-<env>-secrets`

### Owners
- ShiftLink DevOps team
- IAM role/user: `shiftlink-deployer` (or equivalent least-privilege deployment role)

### Rotation cadence
- **Quarterly**, or immediately if compromise is suspected.

### Rotation steps
1. **Prepare**
   - Sign in with the deployment profile (`AWS_PROFILE=shiftlink`).
   - Confirm no deployment is running.
2. **Update secret value**
   - `aws secretsmanager put-secret-value --secret-id SITE_KEY_HMAC_SECRET --secret-string '...new value...'`
3. **Deploy**
   - `cd ~/Desktop/ShiftlinkMain/ShiftlinkMain.xcodeproj`
   - `npx ampx sandbox --once --outputs-format json --outputs-out-dir ..`
4. **Verify**
   - Run a smoke test (AppSync mutation) to ensure Lambdas read the new secret.
5. **Audit**
   - Record the rotation in the change log / ticketing system.

> **Note:** Clients consume the new configuration automatically because Lambdas read the secret on each invocation. No mobile app redeploy is required unless Amplify outputs change.

## 2. PII Retention & Deletion

| Data store | Default retention | Review/Action |
|------------|------------------|---------------|
| Cognito User Pool | Until user deletion | On account closure or data request, run `aws cognito-idp admin-delete-user --user-pool-id <id> --username <email>` |
| DynamoDB (`ShiftlinkMain` tables) | Until item deletion | Delete per-org data via AppSync mutations or `aws dynamodb delete-item` using the org’s key |
| CloudWatch Logs (Lambda, AppSync) | 90 days (configured in schema) | Review quarterly; update retention if policy changes |
| S3 uploads (`shiftlink` bucket) | Follows lifecycle rules (Glacier after 60 days, delete after 365 days) | Adjust lifecycle configuration in S3 console to match compliance needs |

### Purging an Organization
1. Disable user sign-in.
2. Delete related Cognito users (`admin-delete-user`).
3. Remove DynamoDB items (batch job / script filtered on `orgId`).
4. Delete S3 objects under `uploads/<identityId>` for the org’s identities.
5. Record the action in compliance logs.

### Purging a Single User
1. `admin-user-global-sign-out`
2. `admin-delete-user`
3. Remove associated DynamoDB records (e.g., notifications) if stored.
4. Delete S3 objects owned by the user’s `identityId`.

## 3. log Retention & Monitoring

| Service | Retention |
|---------|-----------|
| Lambda logs | 90 days (Amplify logging options) |
| AppSync logs | 90 days (set in AppSync → Settings → Logging) |
| CloudTrail | Enabled account-wide; S3 lifecycle policy applies to the `aws-cloudtrail-logs-*` bucket |

Review alerts and CloudWatch dashboards weekly; keep budgets/alarms for unexpected usage.
