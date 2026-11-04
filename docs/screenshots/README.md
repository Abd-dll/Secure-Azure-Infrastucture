# Screenshot Evidence Index

These screenshots are **supporting evidence**, not a substitute for the Bicep source or the detailed test descriptions in [`../security-validation.md`](../security-validation.md).

> Copy the original PNG files into this directory. This documentation package contains the index only; it does **not** automatically include your screenshot binaries.

## Evidence inventory

| Filename (original) | What it illustrates | Interpretation / caveat |
| --- | --- | --- |
| [`01-resource-group-overview.png`](01-resource-group-overview.png) | Resource inventory using Azure PowerShell | Resource presence; does not by itself validate security settings |
| [`02-vm-managed-identity.png`](02-vm-managed-identity.png) | VM identity set to `SystemAssigned` | Identity enabled; verify principal continuity with RBAC evidence |
| [`03-bastion-ssh.png`](03-bastion-ssh.png) | Active SSH session to the private VM | Administrative access through the lab workflow |
| [`04-private-endpoints.png`](04-private-endpoints.png) | **Key Vault** Private Endpoint connection approved | Connection control-plane approval |
| [`04-private-endpoints(1).png`](04-private-endpoints%281%29.png) | **Storage** Private Endpoint connection approved | Connection control-plane approval |
| [`05-private-dns-resolution.png`](05-private-dns-resolution.png) | Storage and Key Vault hostnames resolve to private IPs | Private DNS resolution from the VM, not full end-to-end authorization proof |
| [`06-rbac-assignments.png`](06-rbac-assignments.png) | Key Vault Secrets User + Storage Blob Data Reader | Storage role observed at **Storage Account scope** |
| [`07-keyvault-security-test.png`](07-keyvault-security-test.png) | Successful Key Vault secret read | Redact the returned secret value |
| [`07-keyvault-security-test(1).png`](07-keyvault-security-test%281%29.png) | Fired Key Vault access alert email | Alert notification; review actual query logic separately |
| [`07-keyvault-security-test(2).png`](07-keyvault-security-test%282%29.png) | Secret write request denied with `403 ForbiddenByRbac` | Negative RBAC validation |
| [`08-storage-private-access.png`](08-storage-private-access.png) | Anonymous Blob request failed with `AuthorizationFailure` | Authentication/authorization failure; **not conclusive firewall evidence** |
| [`08-storage-private-access(1).png`](08-storage-private-access%281%29.png) | Authenticated Blob container listing returned `200 OK` | Positive data-plane listing test |
| [`08-storage-private-access(2).png`](08-storage-private-access%282%29.png) | Fired Blob Storage access alert email | Alert notification; correlation details not visible from email alone |
| [`09-policy-deny-public-ip.png`](09-policy-deny-public-ip.png) | Public IP creation blocked with `RequestDisallowedByPolicy` | Azure Policy enforcement demonstrated |
| [`11-monitoring-logs.png.png`](11-monitoring-logs.png.png) | `AZKVAuditLogs` KQL query and results | Key Vault audit-log ingestion demonstrated |

The filenames in this table match the **submitted screenshots**. There were no separate files named `10-keyvault-alert-fired.png` or `10-storage-alert-fired.png` in the supplied evidence; the original alert email screenshots are listed under `07-...png` and `08-...(1).png`.

## Privacy and consistency checks

Before pushing the image files:

- [ ] Hide actual Key Vault secret values and access tokens.
- [ ] Hide any private SSH key content or passwords.
- [ ] Remove unnecessary subscription IDs and tenant IDs from terminal output if possible.
- [ ] Inspect the **Principal IDs**: the original Managed Identity screenshot and later RBAC screenshot show different IDs. If this is from a VM redeployment, note it in the write-up or replace the outdated screenshot.
- [ ] Preserve command context and error codes so the screenshots remain independently understandable.
- [ ] Confirm that every Markdown hyperlink above opens the intended file on GitHub.

See [Security Validation](../security-validation.md) for the associated test scenarios.
