# E2E AVD Enhancement Backlog

This repository starts as a clean copy of the validated AVD-Landing-Zone baseline. All new user experience, platform capability, and enterprise-operability improvements are implemented here.

## Goals

- Preserve the original project as the validated baseline.
- Expand the deployment UX toward parity with Azure AVD Accelerator patterns where it makes sense.
- Keep enhancements phased so each slice can be validated end to end.

## Phase 1: Image Source Experience

Priority: P0

- Add an image source selector with `Marketplace`, `Azure Compute Gallery`, and optional `Managed Image`.
- Add portal dropdown flows for marketplace publisher, offer, SKU, and version.
- Add portal dropdown flows for compute gallery subscription, resource group, gallery, image definition, and version.
- Add validation for image capabilities such as Gen2 requirements, Trusted Launch compatibility, purchase plan requirements, accelerated networking support, and hibernation support.
- Extend session host deployment to consume either marketplace references or gallery image IDs.
- Add sample parameter files for marketplace and gallery-based deployments.

## Phase 2: Access Assignment Model

Priority: P0

- Support group-based assignment in addition to individual user assignment.
- Support mixed principal types: `User`, `Group`, `ServicePrincipal`, and advanced cases only if justified.
- Separate access assignments for desktop app groups and RemoteApp app groups.
- Add support for group name or UPN resolution instead of forcing raw GUID entry.
- Remove obsolete resolver-era parameters and helper artifacts so the current object-ID model stays internally consistent.
- Replace fixed `principalType: User` behavior with data-driven principal types.

## Phase 3: Identity and Authentication Modes

Priority: P0

- Expand identity service choices to include `ADDS`, `EntraDS`, `EntraID`, and `EntraIDKerberos`.
- Preserve `HybridJoin` only if it maps cleanly to the broader identity model; otherwise unify naming.
- Add Intune enrollment toggle for Entra-joined session hosts.
- Add clearer validation and dependency messaging for domain-based scenarios.
- Add conditional wizard steps based on the selected identity model.

## Phase 4: Host Pool and App Publishing Controls

Priority: P1

- Expose host pool load balancer type.
- Expose max sessions per host.
- Expose personal assignment type for personal host pools (`Automatic` or `Direct`).
- Expose Start VM on Connect plus any supporting RBAC automation.
- Expose custom RDP properties with a recommended default preset and advanced override.
- Replace raw RemoteApp JSON with a structured form-based editor.
- Add a built-in catalog for standard published apps such as Edge, Notepad, Paint, and Task Manager.

## Phase 5: Networking Posture and Connectivity

Priority: P1

- Add `Use existing VNet` versus `Create new VNet` choice.
- Add public network access controls for host pool and workspace.
- Add private endpoint options for storage, Key Vault, and optional AVD private link.
- Add private DNS options when private connectivity is selected.
- Add support for cross-resource-group and cross-subscription selection where possible.
- Add advanced networking controls for DNS, route tables, and ASGs where they materially improve deployment flexibility.

## Phase 6: Security, Monitoring, and Day-2 Operations

Priority: P1

- Add VM security type selection such as `Standard` and `TrustedLaunch`, with conditional secure boot and vTPM settings.
- Add monitoring presets: minimal, recommended, and advanced.
- Add scaling plan deployment and schedule configuration.
- Add brownfield helper flows for adding session hosts, reattaching agents, and enabling Start VM on Connect on existing pools.
- Add human-friendly deployment summary outputs and post-deployment next steps.
- Add richer portal validation and deployment-time diagnostics.

## Phase 7: Naming, Friendly UX, and Docs

Priority: P2

- Add custom friendly names and descriptions for workspace, host pool, app groups, and scaling plan.
- Align all CLI, PowerShell, ARM, Bicep, and managed-app surfaces so the same concepts have the same names.
- Update repository docs after each phase rather than doing a single doc rewrite at the end.
- Add a comparison matrix between baseline and enhanced capabilities.

## Execution Rules

- Validate each phase before starting the next.
- Avoid broad refactors that obscure behavioral changes.
- Keep the copied baseline deployable while adding new options incrementally.
- Prefer additive changes with compatibility defaults.
