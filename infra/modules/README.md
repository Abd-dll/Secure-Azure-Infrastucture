# Bicep Modules

This directory holds the individual Azure resource modules orchestrated by [`../main.bicep`](../main.bicep). The goal is to keep network, compute, data services, identity authorization, governance, and observability **separate but composable**.

## Responsibility boundaries

| Concern | Recommended module | Values usually exposed to `main.bicep` |
| --- | --- | --- |
| VNet and subnets | `network.bicep` | VNet ID, workload subnet ID, Private Endpoint subnet ID |
| Workload VM | `compute.bicep` | VM identity `principalId`, VM/NIC resource IDs |
| Blob Storage | `storage.bicep` | Storage Account ID, container reference where needed |
| Key Vault | `keyvault.bicep` | Key Vault resource ID |
| Private access | `private-endpoints.bicep` | Endpoint IDs or private DNS resources, if consumed |
| Azure RBAC | `rbac.bicep` | Role assignments at deliberate resource scopes |
| Governance | `governance.bicep` | Azure Policy assignment/deployment outputs if needed |
| Observability | `monitoring.bicep` | Workspace and alert resources, if consumed |

**The names and outputs above are an architectural guide, not a verified interface specification.** This documentation package did not include the actual module source files. Keep only the rows and outputs that match the deployed repository.

## Dependency flow

```text
network ──────────────┐
compute ──────────────┼──> private-endpoints / rbac / monitoring
storage ──────────────┤
keyvault ─────────────┘
```

A more precise interpretation:

- **Private Endpoints** depend on the subnet ID and the corresponding Key Vault / Storage Account resource IDs.
- **RBAC** depends on the VM managed identity's `principalId` and target resource IDs.
- **Monitoring** may depend on service/resource IDs and a Log Analytics workspace, depending on the specific module design.
- **Governance** may be deployed before or alongside other resources; a deny policy can block resources intentionally or unexpectedly.

When a module consumes `network.outputs.privateEndpointSubnetId`, for example, Bicep determines the dependency. Avoid broad `dependsOn` declarations when references already express the relationship.

## How the folder is used

The deployment script does **not** deploy the child files individually. It targets `infra/main.bicep`, which references child modules through Bicep `module` declarations with relative paths such as `./modules/network.bicep`.

Review [the infrastructure README](../README.md), [deployment procedure](../../docs/deployment.md), and [Microsoft Learn's Bicep modules guide](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/modules).
