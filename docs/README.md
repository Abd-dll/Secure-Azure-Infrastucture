# Technical Documentation

This folder contains the **engineering record** behind the Secure Azure Infrastructure portfolio project. The top-level [README](../README.md) provides the overview for hiring managers; the documents here explain what was built, how it was deployed and how the security claims were tested.

## Documentation map

| Document | Contents | Audience |
| --- | --- | --- |
| [Architecture](architecture.md) | Azure components, network boundaries, private DNS, identity, RBAC, governance and monitoring | Cloud / Security engineers |
| [Deployment](deployment.md) | Prerequisites, exact repository paths, what to edit in scripts, parameter handling and teardown | Anyone reproducing the lab |
| [Security validation](security-validation.md) | Reproducible security test scenarios, expected vs observed outcomes, evidence and limitations | Cloud Security / SecOps reviewers |
| [Screenshot evidence](screenshots/README.md) | Inventory and mapping of screenshots to security claims | Recruiters and technical reviewers |

## Evidence-driven approach

Each security scenario is documented using this pattern:

1. **Objective / risk:** What does the control attempt to protect?
2. **Precondition:** From which identity and network location was the request executed?
3. **Test:** Which operation was attempted (without publishing tokens or secret values)?
4. **Observed outcome:** Status code, policy error, DNS answer, log entry or alert notification.
5. **Interpretation:** What does the observation establish, and what does it **not** establish?
6. **Evidence:** A relative link to a screenshot in `screenshots/`.

**Do not equate a denied anonymous request with proof of private-network firewall enforcement.** Separate network controls, authentication, RBAC and monitoring whenever describing results.

## Relative Markdown links

- From the **root README**, screenshots live under `docs/screenshots/<filename>.png`.
- From `docs/architecture.md`, `docs/deployment.md` or `docs/security-validation.md`, screenshots live under `screenshots/<filename>.png`.
- From this file, the IaC explanation is at [`../infra/README.md`](../infra/README.md), and PowerShell guidance at [`../scripts/README.md`](../scripts/README.md).

The evidence filenames in this documentation match the originally supplied screenshots, including filenames containing parentheses and the unusual `11-monitoring-logs.png.png` extension. If you rename any images, update their Markdown links consistently.

## Publishing hygiene

- Redact **secret values, bearer tokens, SSH private keys, credentials** and personal contact details.
- Consider redacting **subscription and tenant identifiers** where irrelevant to the technical claim.
- Verify that screenshots taken before and after possible VM recreation do not suggest that two different managed identities are the same principal.
- Keep **operational constraints** in the documentation rather than hiding them (cost, quotas, policy restrictions and permission requirements).
