# Deployment Guide — Secure Azure Infrastructure

This guide describes how the provided **PowerShell orchestration** and **modular Azure Bicep** architecture fit together, including required configuration, environment checks, post-deployment verification and safe cleanup.

> **Reproducibility status:** The uploaded `deploy.ps1` and `cleanup.ps1` are **not ready to run without edits**. The Bicep source files were not attached to this documentation request, so exact Bicep parameter compatibility must be confirmed in the repository before deployment. The observed lab was successfully deployed and validated, but these notes do not claim that an unmodified checkout is one-command reproducible.

## 1. Project paths and execution model

```text
secure-azure-infrastructure/
├── infra/
│   ├── main.bicep                   # Root deployment template
│   └── modules/
│       └── *.bicep                  # Referenced by main.bicep
├── scripts/
│   ├── deploy.ps1                   # Azure login, RG, SSH key, Bicep deployment
│   └── cleanup.ps1                  # Resource deletion — SAFETY REVIEW REQUIRED
└── docs/
    ├── deployment.md
    └── security-validation.md
```

Deployment flow:

```text
PowerShell terminal
      │
      ▼
scripts/deploy.ps1
      ├── Connect-AzAccount
      ├── Create project Resource Group if absent
      ├── Generate SSH key pair (ssh-keygen)
      └── New-AzResourceGroupDeployment
                     │
                     ▼
              infra/main.bicep
                     │
                     ▼
               infra/modules/
                     │
                     ▼
               Azure resources
```

**Important:** `deploy.ps1` does not execute `network.bicep`, `storage.bicep`, or any other module directly. It deploys `infra/main.bicep`, which references those files.

## 2. Prerequisites

### Local tooling

- PowerShell 7 recommended.
- Azure PowerShell **Az modules** installed and available. The supplied deployment script explicitly attempts to import `Az.Accounts` and `Az.Resources`; cleanup additionally requires `Az.KeyVault`.
- Bicep CLI/toolchain compatible with your Azure PowerShell environment.
- `ssh-keygen` available on your machine.
- Optional: Azure CLI, VS Code Bicep extension, PowerShell PSReadLine prediction support.

Validate the tools:

```powershell
$PSVersionTable.PSVersion
Get-Module -ListAvailable Az.Accounts, Az.Resources, Az.KeyVault
Get-Command ssh-keygen
Get-Command bicep -ErrorAction SilentlyContinue
```

These checks show local availability; a missing standalone `bicep` command must be addressed according to the Bicep deployment workflow installed on your machine.

### Azure access

- An active subscription with sufficient funds or credits.
- A region and subscription with quota for the selected VM size and support for the chosen features.
- Permissions to deploy network, compute, Storage, Key Vault, Private Endpoints, Private DNS and Monitor resources.
- **Role assignment permissions** for creating Azure RBAC assignments.
- Appropriate rights for Azure Policy assignments and any custom Policy Definition.
- Extra rights for Key Vault purge, if intentionally required (not needed for ordinary validation).

Role assignment, Policy and Key Vault permissions may be more restrictive than general resource deployment permissions. A successful login does not imply that all these operations are authorized.

### Cost awareness

This lab can create **billable resources**, including the VM and disk, private endpoints, Storage, Key Vault transactions, Log Analytics ingestion/retention and alerting. Prices and offers depend on region, subscription, configuration and usage; no fixed project cost is asserted here. Inspect your Azure subscription's pricing and quotas **before deployment**, and remove lab resources when no longer needed.

## 3. Configure `scripts/deploy.ps1`

The uploaded script currently contains example values; edit them in your local copy before running.

### 3.1. Resource Group and region

The observed lab was associated with a project Resource Group such as `rg-secureinfra-dev-0`, with Azure resources in `spaincentral`. Do not assume this is your required deployment environment or that it is available to every subscription.

Replace the script's placeholders:

```powershell
$location = 'spaincentral'                # Example from the observed lab
$rgName = 'rg-secureinfra-dev-0'          # Example from the observed lab
```

The script creates the Resource Group with tags **only if the group does not exist**. An existing Resource Group's tags are not updated by this implementation.

### 3.2. SSH key location

Replace:

```powershell
$sshKeyPath = '<path_to_ssh_key>'
```

With a private local path, for example:

```powershell
$sshKeyPath = Join-Path $HOME '.ssh/secureinfra_lab_ed25519'
```

`deploy.ps1` calls `ssh-keygen -t ed25519 -f $sshKeyPath`, then passes **only the `.pub` file content** to the Bicep deployment. Check the parent directory exists and avoid overwriting an existing key when rerunning the script. Never commit the private key.

### 3.3. Correct the Bicep file path

In `scripts/deploy.ps1`, **before** the `New-AzResourceGroupDeployment` call, define:

```powershell
$templatePath = (Resolve-Path (Join-Path $PSScriptRoot '../infra/main.bicep')).Path
```

The uploaded version has an invalid template placeholder:

```powershell
# Existing placeholder (NOT executable):
# -TemplateFile <"file_path">
```

Replace it **inside the existing command** with:

```powershell
-TemplateFile $templatePath
```

Explanation: `$PSScriptRoot` resolves to `.../secure-azure-infrastructure/scripts`, `../infra/main.bicep` resolves to its sibling `infra` directory, and Bicep resolves `./modules/...` references relative to `main.bicep`.

The **same resolved variable** can be used in the script's commented `-WhatIf` deployment example when you enable it.

### 3.4. Verify deployment parameter names and values

The uploaded deployment invocation passes:

| Script argument | Current value in the uploaded script | Required action |
| --- | --- | --- |
| `-sshKey` | SSH `.pub` file content | Check `main.bicep` defines the matching parameter |
| `-vmSize` | `Standard_D2s_v4` | Check quota, availability and matching Bicep parameter |
| `-storageName` | `example` | Replace with a **globally unique** valid Storage Account name |
| `-kvName` | `example` | Replace with a **globally unique** valid Key Vault name |
| `-TemplateFile` | ` <"file_path"> ` placeholder | Replace with `$templatePath` as explained above |
| `-ResourceGroupName` | `$rgName` | Use the intended project-only RG |

The script **does not visibly pass a Key Vault secret parameter**. If the root Bicep template expects one (for example, `@secure() param secretValue string`), supply it using a secure workflow and declare the receiving module parameter secure as well. Never place real secret values directly in version-controlled Bicep or scripts.

### 3.5. Select the subscription explicitly

The uploaded script executes `Connect-AzAccount`. If your account has more than one subscription, verify its context and select the right subscription **before any deployment or deletion**:

```powershell
Connect-AzAccount
Get-AzContext
Get-AzSubscription | Select-Object Name, Id
Set-AzContext -SubscriptionId '<intended-subscription-id>'
Get-AzContext
```

The script also invokes `Connect-AzAccount` itself; setting the context before execution does not guarantee it will remain selected if the script's authentication changes context. **Inspect the context after the login inside the script**, or update the script to choose the intended subscription explicitly.

## 4. Validate, preview and deploy

Before running the script, make sure this file exists:

```powershell
Test-Path './infra/main.bicep'
```

If the Bicep CLI is available, a local syntax/build check can help:

```powershell
bicep build ./infra/main.bicep
```

Compilation is **not** an Azure permission, quota or policy compliance check. A successful build does not guarantee successful deployment.

### Preview with What-If

The existing script includes a commented `New-AzResourceGroupDeployment ... -WhatIf` example. **Fix its placeholders, paths, and parameters first**, then uncomment/run it to preview planned Azure changes.

For illustration, from the repository root and **with parameters confirmed against your actual `main.bicep`**:

```powershell
$rgName = '<project-resource-group>'
$templatePath = (Resolve-Path './infra/main.bicep').Path
$sshPubKey = (Get-Content "$HOME/.ssh/secureinfra_lab_ed25519.pub" -Raw).Trim()

New-AzResourceGroupDeployment `
  -Name 'secure-infra-preview' `
  -ResourceGroupName $rgName `
  -TemplateFile $templatePath `
  -sshKey $sshPubKey `
  -vmSize 'Standard_D2s_v4' `
  -storageName '<unique-storage-name>' `
  -kvName '<unique-key-vault-name>' `
  -WhatIf
```

This preview assumes the Resource Group exists and the template has those parameters. Supply any other required parameters through a secure method.

### Execute the script

After the edits and preview:

```powershell
# From repository root
./scripts/deploy.ps1
```

The script creates the Resource Group if missing, generates the SSH key pair and invokes Azure PowerShell's `New-AzResourceGroupDeployment`. On success, it checks the returned deployment's `ProvisioningState`.

**Do not interpret `Succeeded` as proof that the security requirements are met.** Continue with the validation checklist.

## 5. Post-deployment verification

### Resource inventory

```powershell
$rgName = '<project-resource-group>'
Get-AzResource -ResourceGroupName $rgName |
  Select-Object Name, ResourceType
```

### Managed identity and Azure RBAC

```powershell
$vm = Get-AzVM -ResourceGroupName $rgName -Name '<vm-name>'
$vm.Identity | Format-List *

Get-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId |
  Select-Object RoleDefinitionName, Scope
```

Confirm the VM's System-Assigned Managed Identity is enabled. **Scopes matter:** in the observed lab, `Storage Blob Data Reader` was at **Storage Account** scope, and `Key Vault Secrets User` at **Key Vault** scope.

### Private Endpoints and DNS

Verify connection approval in Azure PowerShell/Portal. Inside the private Ubuntu VM, resolve the normal service hostnames:

```bash
nslookup <storage-account>.blob.core.windows.net
nslookup <key-vault>.vault.azure.net
```

In the provided evidence, these returned `10.40.2.20` and `10.40.2.30`, respectively. DNS resolution only verifies the naming path; actual service access requires valid networking and authorization.

### Logs and alerts

Open the Log Analytics workspace and query the Key Vault audit table if configured for resource-specific logs:

```kusto
AZKVAuditLogs
| project TimeGenerated, OperationName, ResultType
| sort by TimeGenerated desc
| take 20
```

Check the specific configured alert rules, action group/email destination, evaluation configuration and alert-firing history. Screenshot evidence shows notifications were received in the lab, but the exact KQL alert rules were not supplied with this documentation request.

See [security-validation.md](security-validation.md) for the detailed positive/negative test matrix.

## 6. Cleanup and cost control

> **WARNING — the uploaded `cleanup.ps1` should NOT be executed unchanged.** It attempts to delete `NetworkWatcherRG` as well as the project Resource Group and permanently purge a soft-deleted Key Vault.

### Mandatory checks

1. **Verify the active subscription** (`Get-AzContext`).
2. Verify `$rgName` identifies the **dedicated lab Resource Group** and list all its resources.
3. **Remove the `Remove-AzResourceGroup -Name NetworkWatcherRG` operation** unless you have separately established that this Resource Group is exclusively owned by the lab and safe to delete. It may be shared or managed independently.
4. Identify the **exact** project Key Vault; the script's `(Get-AzKeyVault -ResourceGroupName $rgName).Name` may return multiple names.
5. Decide whether the Key Vault should be **soft deleted only**. Purging is irreversible and requires permissions; **purge protection** can make early purge impossible.
6. Obtain explicit confirmation before deleting any resource group.
7. After deletion, verify the project resources are gone and check for any resources outside the project RG (only if intentionally created).

Useful **inspection commands**:

```powershell
$rgName = '<project-resource-group>'
Get-AzContext
Get-AzResourceGroup -Name $rgName
Get-AzResource -ResourceGroupName $rgName | Select-Object Name, ResourceType
Get-AzKeyVault -ResourceGroupName $rgName | Select-Object VaultName, ResourceGroupName, Location
```

For a **project-only** Resource Group, a deliberately reviewed deletion can be initiated manually after confirming the scope:

```powershell
Remove-AzResourceGroup -Name $rgName -WhatIf
# Review the target and consequences before any real deletion.
# Remove-AzResourceGroup -Name $rgName
```

This is an alternative approach for a disposable lab RG, **not** an endorsement of unattended deletion and **not** equivalent to the uploaded script's purge behavior. Key Vault soft-deleted names can remain reserved during retention unless properly purged; purge protection governs whether permanent deletion is permitted.

## 7. Troubleshooting

| Symptom | Check first |
| --- | --- |
| PowerShell fails near `-TemplateFile` | ` <"file_path"> ` placeholder was not replaced with `$templatePath` |
| `main.bicep` file not found | `$PSScriptRoot` relative path and actual repository structure |
| Deployment parameter binding error | Check `main.bicep` parameters against `sshKey`, `vmSize`, `storageName`, `kvName` and additional secure parameters |
| VM SKU is unavailable or deployment fails quota checks | Region, current VM family quota, subscription restrictions |
| RBAC deployment rejected | Role assignment permissions and actual assignment scope |
| Policy rejects deployment | Which resource type and scope the denial applies to |
| Private name resolves publicly | Private DNS zone, VNet link and Private Endpoint DNS Zone Group |
| Access fails despite private DNS | Service network settings **and** Microsoft Entra token audience **and** RBAC permissions |
| Purge fails | Purge protection, Key Vault recovery retention, permissions, vault location |

## References

- [Deploy with PowerShell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell)
- [Bicep modules and relative paths](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules)
- [Bicep parameters and `@secure()`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters)
- [Key Vault soft-delete and purge](https://learn.microsoft.com/en-us/azure/key-vault/general/key-vault-recovery)
- [Azure Private Endpoint DNS](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)
