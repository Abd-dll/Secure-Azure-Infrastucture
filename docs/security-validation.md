# Security Validation — Secure Azure Infrastructure

**Purpose:** Demonstrate which security controls were exercised in the Azure lab, the observed results, and the limits of each conclusion. This document links **configuration**, **test behavior**, **logs**, and **alerts**, instead of treating resource deployment success as sufficient security evidence.

> **Evidence standard:** A passing scenario is based on the supplied screenshots. Exact alert-rule KQL, full network firewall state, and the complete Bicep source were not provided for this documentation request, so these are not independently certified here. Never publish credentials, bearer tokens or real secret values to reproduce the tests.

## 1. Tested environment and trust boundaries

| Component | Observed configuration / role |
| --- | --- |
| Ubuntu VM | Private IP `10.40.1.4` in workload subnet `10.40.1.0/24` |
| Virtual Network | `10.40.0.0/16` |
| Private Endpoints subnet | `10.40.2.0/27` |
| Blob Private Endpoint | `10.40.2.20` |
| Key Vault Private Endpoint | `10.40.2.30` |
| VM workload identity | System-assigned managed identity |
| Key Vault authorization | `Key Vault Secrets User` assigned to managed identity at Key Vault scope |
| Storage authorization | `Storage Blob Data Reader` assigned to managed identity at **Storage Account** scope |
| Governance | Resource Group Azure Policy denying Public IP resource deployment |
| Observability | Key Vault Audit Logs in `AZKVAuditLogs`; Key Vault and Blob Storage alert notifications |

Security boundaries evaluated here: **administrative access**, **private DNS/connectivity**, **identity and authorization**, **deployment governance**, and **monitoring**. These are distinct and must not be conflated.

## 2. Validation matrix

| ID | Control / scenario | Expected | Observed | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| NET-01 | Private Endpoint connection approval | Both service connections approved | `Approved`, provisioning `Succeeded` | **PASS** | [Storage](screenshots/04-private-endpoints%281%29.png), [Key Vault](screenshots/04-private-endpoints.png) |
| NET-02 | Private DNS from VM | Service FQDNs resolve to endpoint private IPs | Blob `10.40.2.20`; Key Vault `10.40.2.30` | **PASS** | [DNS output](screenshots/05-private-dns-resolution.png) |
| VM-01 | VM administrative entry | SSH session available without VM public IP | Bastion Developer SSH session visible | **PASS (session)** | [SSH session](screenshots/03-bastion-ssh.png) |
| IAM-01 | VM managed identity | System-assigned identity enabled | `SystemAssigned` visible | **PASS (configuration)** | [Managed identity](screenshots/02-vm-managed-identity.png) |
| IAM-02 | Target RBAC assignments | Key Vault reader / Blob reader roles present | Both visible, with explicit scopes | **PASS (configuration)** | [RBAC](screenshots/06-rbac-assignments.png) |
| KV-01 | Read test secret from VM | Authorized read | Secret object returned | **PASS** | [Successful read](screenshots/07-keyvault-security-test.png) |
| KV-02 | Attempt secret modification | Write denied without permission | `HTTP 403 ForbiddenByRbac` | **PASS** | [Denied write](screenshots/07-keyvault-security-test%282%29.png) |
| ST-01 | Authenticated container listing | Container listing permitted | `HTTP 200 OK`, XML result with empty `<Blobs />` | **PASS** | [Storage HTTP 200](screenshots/08-storage-private-access%281%29.png) |
| ST-02 | Unauthenticated request | Access denied | `AuthorizationFailure` | **PASS (auth denial only)** | [Denied request](screenshots/08-storage-private-access.png) |
| GOV-01 | Create Public IP in protected RG | Azure Policy rejects deployment | `RequestDisallowedByPolicy`, HTTP `403` | **PASS** | [Policy denial](screenshots/09-policy-deny-public-ip.png) |
| MON-01 | Key Vault audit ingestion | Events queryable in Log Analytics | `AZKVAuditLogs` events visible | **PASS** | [Audit logs](screenshots/11-monitoring-logs.png.png) |
| MON-02 | Key Vault unauthorized access alert | Alert notification delivered | `Fired` notification email observed | **PASS (notification)** | [Key Vault alert](screenshots/07-keyvault-security-test%281%29.png) |
| MON-03 | Blob Storage unauthorized access alert | Alert notification delivered | `Fired` notification email observed | **PASS (notification)** | [Blob alert](screenshots/08-storage-private-access%282%29.png) |

**Not counted as proved:** A network-specific public-access denial, an authenticated retrieval of an **existing blob's contents**, or a full identity-token claim verification. These would require additional evidence. The successful Storage request enumerated an **empty container**, which is still a valid authorized data-plane operation.

## 3. Private networking

### NET-01 — Private Endpoint approval

**Objective:** Establish managed private connectivity to Azure Blob Storage and Key Vault.

**Setup:** Private Endpoints associated with the service resources and the Private Endpoint subnet.

**Observed:** The PowerShell output displayed `ProvisioningState: Succeeded` and private connection status `Approved` for each service.

**Conclusion:** Azure accepted the Private Endpoint connections. Approval alone does not prove that a VM resolves the service to the private IP or has data-plane access; those are verified independently in NET-02 and service tests.

Evidence: [Storage connection](screenshots/04-private-endpoints%281%29.png) · [Key Vault connection](screenshots/04-private-endpoints.png)

### NET-02 — Private DNS resolution

**Objective:** Verify the workload resolves standard service hostnames to private endpoint IPs.

**From:** The Ubuntu VM.

**Commands (replace names with actual deployed resource names):**

```bash
nslookup <storage-account>.blob.core.windows.net
nslookup <key-vault>.vault.azure.net
```

**Observed:**

```text
Blob hostname  -> privatelink.blob.core.windows.net  -> 10.40.2.20
Vault hostname -> privatelink.vaultcore.azure.net     -> 10.40.2.30
```

**Conclusion:** Private DNS resolution works for both services from the workload. This is a networking prerequisite; it is **not** a grant of identity permissions.

Evidence: [DNS lookups](screenshots/05-private-dns-resolution.png)

## 4. Identity and least-privilege RBAC

### IAM-01 / IAM-02 — Workload identity and role scope

**Objective:** Allow service access through a system-assigned managed identity instead of an embedded application credential.

**Observed:** The VM identity was enabled and Azure role assignments were visible:

| Role | Scope shown in evidence | Why it matters |
| --- | --- | --- |
| `Key Vault Secrets User` | Key Vault | Allows reading secret values without a general right to set/update secrets |
| `Storage Blob Data Reader` | Storage Account | Allows Blob data read operations within the scope, without writes |

**Least-privilege note:** The Blob role can be further limited to the intended Blob container. The observed assignment is **not container-scoped**, and the documentation must not claim otherwise.

**Evidence consistency note:** One earlier VM identity screenshot shows a different `PrincipalId` from the later RBAC screenshot. This could reflect a VM/identity recreation, but the cause is **not verified**. Before publication, use matching evidence or explicitly note the lifecycle change; do not claim these screenshots necessarily refer to the same principal instance.

Evidence: [Managed identity](screenshots/02-vm-managed-identity.png) · [Role assignments](screenshots/06-rbac-assignments.png)

### KV-01 — Authorized Key Vault secret read

**Objective:** Verify the VM-side authenticated call is permitted to read a test secret.

**From:** VM SSH session; REST API call with an Azure token held in a shell variable (token **not** disclosed in documentation).

**Request shape (illustrative):**

```http
GET https://<key-vault>.vault.azure.net/secrets/<test-secret>?api-version=7.4
Authorization: Bearer <REDACTED_TOKEN>
```

**Observed:** A response containing a secret object was returned. The secret's value and identifying portion were redacted in the evidence.

**Conclusion:** The REST read completed successfully from the private VM test context. Do not publish the original unredacted response.

Evidence: [Successful secret read](screenshots/07-keyvault-security-test.png)

### KV-02 — Denied Key Vault secret write

**Objective:** Validate that a principal with a read-oriented Key Vault role cannot set/update a secret.

**From:** The VM session, using the same lab token-based request workflow.

**Request shape (illustrative):**

```http
PUT https://<key-vault>.vault.azure.net/secrets/<test-secret>?api-version=7.4
Authorization: Bearer <REDACTED_TOKEN>
Content-Type: application/json

{"value":"<NON_SENSITIVE_TEST_VALUE>"}
```

**Observed:** `HTTP/1.1 403 Forbidden`; response body included `ForbiddenByRbac` and the denied `Microsoft.KeyVault/vaults/secrets/setSecret/action` operation. The response headers also contained Private Link connection context.

**Conclusion:** The role evaluated for that request did not grant secret-write access. This is a meaningful negative authorization test, distinct from proving network isolation.

Evidence: [RBAC write denial](screenshots/07-keyvault-security-test%282%29.png)

## 5. Blob Storage authorization

### ST-01 — Successful authenticated container listing

**Objective:** Verify the VM can perform a permitted authenticated Blob Storage operation.

**From:** VM SSH session; request with a bearer token.

**Request shape (illustrative):**

```http
GET https://<storage-account>.blob.core.windows.net/data?restype=container&comp=list
Authorization: Bearer <REDACTED_TOKEN>
x-ms-version: 2023-11-03
```

**Observed:** `HTTP/1.1 200 OK` and an XML container listing, with `<Blobs />` indicating no blobs were returned in the listing.

**Conclusion:** Authenticated **container listing** succeeded. This is not evidence of downloading actual blob contents and does not validate Blob write permissions (the assigned role is Reader).

Evidence: [Container listing, HTTP 200](screenshots/08-storage-private-access%281%29.png)

### ST-02 — Rejected unauthenticated request

**Objective:** Confirm an anonymous/unauthenticated request is not allowed to list the protected container.

**From:** A PowerShell request without the VM's bearer authorization.

**Observed:** `Invoke-WebRequest` returned `AuthorizationFailure`.

**Conclusion:** The request was rejected, but **this error does not establish which security boundary rejected it**. It could result from the lack of required authentication/authorization and must not be presented as stand-alone proof that public network access is disabled. A separate network-specific test or resource configuration inspection is required to establish that claim.

Evidence: [Failed anonymous request](screenshots/08-storage-private-access.png)

## 6. Deployment governance

### GOV-01 — Azure Policy denies Public IP deployment

**Objective:** Prevent creation of Public IP address resources in the protected Resource Group.

**From:** Azure PowerShell using an account that attempted to deploy a Public IP.

**Command shape (resource name and target RG are illustrative):**

```powershell
New-AzPublicIpAddress `
  -ResourceGroupName '<protected-project-rg>' `
  -Name 'testPIP' `
  -Location '<allowed-azure-region>' `
  -AllocationMethod Static
```

**Observed:** The command returned HTTP `403`, with `RequestDisallowedByPolicy` and an assignment named `Deny Public IP`. The diagnostic output referenced the built-in policy definition `Not allowed resource types`.

**Conclusion:** The scoped Azure Policy prevented the selected `Microsoft.Network/publicIPAddresses` resource deployment, even though the request was issued through Azure PowerShell. This supports the governance control for the protected Resource Group; it does not automatically describe behavior in other Resource Groups.

Evidence: [Denied Public IP deployment](screenshots/09-policy-deny-public-ip.png)

## 7. Logging and alerting

### MON-01 — Key Vault audit ingestion

**Objective:** Verify that Key Vault audit events are available for investigation.

**Destination:** Azure Log Analytics Workspace, resource-specific `AZKVAuditLogs` table.

**KQL as shown in the evidence:**

```kusto
AZKVAuditLogs
| project TimeGenerated, OperationName, ResultType
| sort by TimeGenerated desc
| take 20
```

**Observed:** Key Vault operations such as `SecretSet`, `Authentication`, `AfterAuthentication`, and `VaultGet` appeared with `Success` results in the screenshot.

**Conclusion:** Events are being ingested and are queryable. **This particular screenshot does not show the denied secret-write event**, so it should not be cited as proof of that specific error's ingestion.

Evidence: [Log Analytics KQL results](screenshots/11-monitoring-logs.png.png)

### MON-02 / MON-03 — Azure Monitor notifications

**Objective:** Surface configured unauthorized-access patterns through alert rules and email notifications.

**Observed:** Two Azure Monitor emails with status **`Fired`**, severity **`Sev2`**:

- `Unauthorized Key Vault Access`
- `Unauthorized Blob Storage Access`

**Conclusion:** The configured alert notifications fired and reached the email recipient. The screenshots alone do not reveal the **full KQL expression**, evaluation interval, threshold or which exact logged row caused each firing. Those details should be checked directly in `monitoring.bicep` and the alert rule configuration if deeper reproducibility is required.

Evidence: [Key Vault alert](screenshots/07-keyvault-security-test%281%29.png) · [Blob Storage alert](screenshots/08-storage-private-access%282%29.png)

## 8. Security interpretation and known gaps

| Claim | Supported by available evidence? | Further verification if required |
| --- | --- | --- |
| Private Endpoint connections approved | **Yes** | None for the approval claim |
| VM resolves both PaaS hostnames to private endpoint IPs | **Yes** | None for DNS resolution claim |
| VM read Key Vault test secret | **Yes, observed** | Correlate token principal with active VM identity if a strict provenance audit is needed |
| VM denied Key Vault write | **Yes** | Capture matching audit failure in Log Analytics to show full event correlation |
| VM listed Storage container | **Yes** | Add Blob GET against an existing test blob if content retrieval is a requirement |
| Anonymous Blob request rejected | **Yes** | Check exact service network configuration for public firewall isolation claim |
| Public network access was definitively blocked by the Storage firewall | **Not independently established by the provided negative request** | Inspect effective Storage networking settings and use a controlled, appropriately authenticated external network test |
| Azure Policy blocked Public IP creation in the protected RG | **Yes** | Optional: evaluate policy compliance report |
| Key Vault diagnostic logs reached Log Analytics | **Yes** | Capture an error-specific audit event for end-to-end incident traceability |
| Two alert notifications fired | **Yes** | Record exact rule query and correlation details for a fully reproducible detection test |

This is a **focused security-control validation lab**. It does not claim exhaustive threat modeling, production hardening, independent penetration testing, SOC coverage, or Zero Trust certification.

## 9. Suggested next validation work

1. **Network verification:** Record the effective public-network settings for Key Vault and Storage, then distinguish service networking denial from missing authentication.
2. **RBAC hardening:** Scope `Storage Blob Data Reader` to the intended container if workload requirements permit.
3. **Monitoring traceability:** Query and screenshot the precise unauthorized event that caused an alert; include the alert-rule KQL, frequency, threshold and action group configuration.
4. **Identity continuity:** Align VM managed identity and RBAC screenshots from one deployment, or document why principal IDs changed.
5. **Automation:** Add non-secret build/validation checks and deliberately scoped deployment/cleanup safeguards.

## Sources

- [Azure RBAC assignments with Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-rbac)
- [Azure Private Endpoint overview](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure Private Endpoint DNS](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)
- [Azure Monitor — overview](https://learn.microsoft.com/en-us/azure/azure-monitor/overview)
- [Azure Policy — overview](https://learn.microsoft.com/en-us/azure/governance/policy/overview)
