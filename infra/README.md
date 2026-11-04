# Infrastructure as Code — Azure Bicep

This directory contains the **Infrastructure as Code** definition for the Secure Azure Infrastructure lab. Bicep expresses the target Azure resource configuration; **PowerShell scripts handle local prerequisites, authentication, Resource Group setup, parameter values, and deployment invocation**.

## Entry point and path resolution

```text
repository root/
├── infra/
│   ├── main.bicep                 <-- Deployment entry point
│   └── modules/
│       ├── network.bicep
│       ├── compute.bicep
│       ├── storage.bicep
│       ├── keyvault.bicep
│       ├── private-endpoints.bicep
│       ├── rbac.bicep
│       ├── governance.bicep
│       └── monitoring.bicep
└── scripts/
    └── deploy.ps1                <-- Invokes infra/main.bicep
```

**Note:** Module filenames above reflect the logical project organization discussed during implementation; verify and adjust the table to match the actual files in this repository. The Bicep source files were not included with the documentation request, so this README does not claim to have validated their exact declarations.

### PowerShell → Bicep

`scripts/deploy.ps1` uses `New-AzResourceGroupDeployment -TemplateFile` and passes Bicep parameter names such as `sshKey`, `vmSize`, `storageName`, and `kvName`.

From inside `scripts/deploy.ps1`, resolve the template relative to the **script location**, not the user's current terminal folder:

```powershell
$templatePath = (Resolve-Path (Join-Path $PSScriptRoot '../infra/main.bicep')).Path
```

Then use the resolved path in the existing deployment call:

```powershell
-TemplateFile $templatePath
```

**These are edit instructions, not a standalone copy/paste script.** Replace the existing invalid placeholder `-TemplateFile <"file_path">` with the actual expression. `$PSScriptRoot` is the directory containing the running `.ps1` file; the relative path works whether the script was started from the repository root or another working directory.

### `main.bicep` → modules

Bicep module references use paths relative to the **Bicep file containing the declaration**. Example only:

```bicep
module network './modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    // Actual parameters depend on network.bicep
  }
}
```

Module outputs let `main.bicep` pass resource IDs to dependent modules, such as private endpoint subnet ID, Storage Account ID, Key Vault ID and VM managed identity principal ID. Bicep can infer deployment dependencies from these output references.

## Logical module responsibilities

| Module (illustrative filename) | Responsibility |
| --- | --- |
| `network.bicep` | VNet, subnets, Network Security Group and associations |
| `compute.bicep` | Private Ubuntu VM, network interface and system-assigned managed identity |
| `storage.bicep` | Storage Account and private Blob container |
| `keyvault.bicep` | Key Vault and any securely supplied test secret |
| `private-endpoints.bicep` | Private Endpoints, Private DNS Zones, VNet Links and DNS Zone Groups |
| `rbac.bicep` | Role assignments to the VM managed identity |
| `governance.bicep` | Azure Policy definition/assignment to deny Public IP addresses |
| `monitoring.bicep` | Log Analytics, diagnostic settings, action group and alert rules, as implemented |

See [modules/README.md](modules/README.md) for expected cross-module dependencies and [architecture](../docs/architecture.md) for the observed environment.

## Parameter contract: check before running

The **provided** `scripts/deploy.ps1` passes:

| PowerShell switch | Script value | Bicep requirement |
| --- | --- | --- |
| `-sshKey` | Contents of generated SSH **public** key file | `param sshKey ...` or equivalent |
| `-vmSize` | `Standard_D2s_v4` | `param vmSize ...` or equivalent |
| `-storageName` | `example` placeholder | `param storageName ...` or equivalent |
| `-kvName` | `example` placeholder | `param kvName ...` or equivalent |

The **exact** parameters in `main.bicep` have not been independently verified here. If the template has additional required parameters (including a secure Key Vault secret), the deployment call must supply them securely. Never place real secrets in tracked `.bicepparam` files, template defaults, outputs, or shell histories.

## Direct deployment for debugging (optional)

If `infra/main.bicep` is a **resource-group-scoped** Bicep file and its parameters match the examples, the equivalent direct PowerShell command has this form:

```powershell
$rgName = '<your-project-resource-group>'
$templatePath = (Resolve-Path './infra/main.bicep').Path

New-AzResourceGroupDeployment `
  -Name 'secure-infra-deployment' `
  -ResourceGroupName $rgName `
  -TemplateFile $templatePath `
  -sshKey (Get-Content "$HOME/.ssh/secureinfra_lab_ed25519.pub" -Raw).Trim() `
  -vmSize 'Standard_D2s_v4' `
  -storageName '<globally-unique-storage-name>' `
  -kvName '<globally-unique-key-vault-name>' `
  -WhatIf
```

This command **previews** a deployment; remove `-WhatIf` only after examining the result and supplying any additional required parameters. It is illustrative until the actual Bicep parameter list has been checked.

## Security and change management

- Do not assign VM public IPs as a workaround for private connectivity tests.
- Keep Bicep modules parameterized instead of storing environment-specific secrets.
- Validate RBAC assignment scopes: in the observed lab, the Storage Reader assignment was scoped to the Storage Account.
- Use `-WhatIf` to preview significant changes and review role-assignment permissions.
- Deleting the resource group is destructive. Review [deployment and cleanup](../docs/deployment.md).

## Official documentation

- [Bicep modules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules)
- [Deploy resources with Azure PowerShell](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell)
- [Bicep parameters and `@secure()`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters)
