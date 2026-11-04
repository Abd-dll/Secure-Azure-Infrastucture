# PowerShell Automation Scripts

This folder provides **local orchestration around the Bicep infrastructure**. The scripts do not replace Bicep: `deploy.ps1` prepares the Azure context and invokes `../infra/main.bicep`; `cleanup.ps1` attempts to remove resources when the lab is finished.

> **Current state:** Both supplied scripts contain configuration placeholders. `deploy.ps1` cannot be used unchanged, and `cleanup.ps1` includes destructive operations that should be revised before running. These notes describe the **actual uploaded scripts**, not a revised or production-hardened implementation.

## Scripts

| File | What the provided version does | Key consideration |
| --- | --- | --- |
| [`deploy.ps1`](deploy.ps1) | Configures PowerShell tab completion, imports available modules, authenticates with `Connect-AzAccount`, creates the Resource Group if missing, generates an Ed25519 SSH key pair, then calls `New-AzResourceGroupDeployment` | Template path, names, region and SSH key location are placeholders; Bicep parameters must match |
| [`cleanup.ps1`](cleanup.ps1) | Looks up Key Vault(s) in the configured Resource Group, attempts Key Vault deletion and purge, removes the project Resource Group, and **also attempts to delete `NetworkWatcherRG`** | Potentially destructive outside the project; purge may be blocked by purge protection / permissions |

## Required local prerequisites

- **PowerShell 7** recommended, a working `ssh-keygen`, and network access to Azure Resource Manager.
- An installed **Az PowerShell** environment (`Az.Accounts`, `Az.Resources`, and `Az.KeyVault` for cleanup).
- **Bicep tooling** available to the supported Azure PowerShell deployment workflow.
- Suitable subscription and Azure permissions for resources, role assignments, Policy assignments and Key Vault operations.
- Region availability and quotas, especially for the chosen VM size.
- `PSReadLine` features compatible with the configured completion/prediction functions, or remove those optional UX lines.

The script also registers optional **Azure CLI** tab completion. That does **not** mean the script deploys through Azure CLI; the actual deployment uses Azure PowerShell (`New-AzResourceGroupDeployment`).

## How `deploy.ps1` connects to Bicep

Expected repository paths:

```text
repository-root/
├── infra/
│   ├── main.bicep
│   └── modules/
└── scripts/
    ├── deploy.ps1
    └── cleanup.ps1
```

Inside `deploy.ps1`, add this **before the deployment call**:

```powershell
$templatePath = (Resolve-Path (Join-Path $PSScriptRoot '../infra/main.bicep')).Path
```

And replace the uploaded placeholder:

```powershell
# Before (placeholder; do not run):
# -TemplateFile <"file_path">

# After (inside the existing New-AzResourceGroupDeployment call):
-TemplateFile $templatePath
```

`$PSScriptRoot` makes the path independent of the directory from which you launch PowerShell. The Bicep file itself resolves its own module paths relative to `infra/main.bicep`.

The current script passes `-sshKey`, `-vmSize`, `-storageName`, and `-kvName` to the Bicep deployment command. Compare those switches with the actual `param` declarations in `main.bicep` before running. Additional required secure parameters must be handled separately and safely.

## Configure `deploy.ps1` before execution

1. Replace `$location = "example"` with the intended Azure region (the observed lab resources were in `spaincentral`).
2. Replace `$rgName = "example"` with the **project-only** Resource Group name.
3. Replace example tag values with meaningful project tags.
4. Replace `$sshKeyPath = "<path_to_ssh_key>"` with a **private, absolute local path**, for example `Join-Path $HOME '.ssh/secureinfra_lab_ed25519'`. Do not commit the generated private key.
5. Add `$templatePath` as shown above and replace the invalid template path placeholder.
6. Replace the `-storageName "example"` and `-kvName "example"` argument values with globally unique valid names.
7. Check the chosen `-vmSize 'Standard_D2s_v4'` against your subscription quota, region and intended cost.
8. Verify that all parameters expected by `main.bicep` are provided, including any `@secure()` secret parameter. The uploaded script does not visibly pass such a secret parameter.
9. Confirm the current subscription with `Get-AzContext`, or explicitly set it with `Set-AzContext` before deploying.
10. Review the commented `-WhatIf` example and run a preview first, after fixing its placeholder values and template path.

**SSH key caveat:** The script always calls `ssh-keygen`. If the target key already exists, `ssh-keygen` may ask whether to overwrite it; overwriting an in-use key could interrupt future SSH access. Review the file path before rerunning.

### Run (only after the edits above)

From the **repository root**:

```powershell
./scripts/deploy.ps1
```

From the **scripts folder**:

```powershell
./deploy.ps1
```

Review the detailed [deployment guide](../docs/deployment.md) first, including the Azure subscription and permission checks.

## `cleanup.ps1`: mandatory safety review

The uploaded script currently executes the following types of operations:

```powershell
Remove-AzKeyVault -ResourceGroupName $rgName -VaultName $VaultName
Remove-AzKeyVault -VaultName $VaultName -InRemovedState -Location $location
Remove-AzResourceGroup -Name $rgName
Remove-AzResourceGroup -Name NetworkWatcherRG
```

**Do not run this script as-is.** In particular:

- **Remove the `NetworkWatcherRG` deletion** unless you have explicitly identified the Resource Group, its owner, and all resources it contains. It is not inherently part of this project.
- Ensure `$rgName` identifies **only** your lab Resource Group and that `Get-AzKeyVault -ResourceGroupName $rgName` returns the intended vault. Multiple vaults require unambiguous handling.
- **Key Vault purge is irreversible** and may be prohibited if purge protection is enabled. Treat it as an optional, separately approved administrative action, not a routine cleanup step.
- Confirm `Get-AzContext` before making any deletion.
- The provided script has no explicit guard requiring typed confirmation of the project Resource Group. Consider adding one before publishing or executing cleanup.

If you only want to remove the dedicated lab Resource Group, a simpler manually reviewed approach is possible, but Key Vault soft-deleted naming restrictions and other external resources may remain. See [deployment.md](../docs/deployment.md#cleanup-and-cost-control) for the safe checklist.

## Operational notes

- The deployment script **creates** a Resource Group if it does not exist, but does **not** refresh tags when it already exists.
- `Connect-AzAccount` authenticates but does **not** by itself guarantee that the desired subscription is selected in multi-subscription accounts.
- The deployment name is currently hardcoded to `1stDeploymentProjectTest`.
- The script has a `try/catch` around the Bicep deployment and checks the deployment `ProvisioningState`, but this does not replace validating all intended security controls afterward.
- PowerShell output and command histories must not include plaintext secrets or bearer tokens.

## References

- [Deploy an ARM/Bicep template with PowerShell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell)
- [Azure Key Vault recovery and purge](https://learn.microsoft.com/en-us/azure/key-vault/general/key-vault-recovery)
- [Secure parameters in Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters)
