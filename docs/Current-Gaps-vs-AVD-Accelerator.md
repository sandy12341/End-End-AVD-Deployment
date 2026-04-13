# Current Gaps vs AVD Accelerator

This document captures the main capability and user-experience gaps identified by comparing the copied baseline project to Azure's AVD Accelerator.

## Summary

The baseline project is intentionally simpler and more opinionated. It already provides a usable deployment experience, but it exposes fewer choices in the areas where enterprise users typically expect flexibility.

## Gap Areas

### 1. Image Selection

Current baseline:
- Session host image defaults are effectively fixed to a marketplace Windows 11 AVD image.
- There is no first-class image source selector in the main deployment UX.

Accelerator-inspired enhancement:
- Add marketplace versus compute gallery selection.
- Add dropdown-based image browsing and validation.
- Support purchase-plan-aware marketplace images.

### 2. Identity Service Breadth

Current baseline:
- Main deployment surface is centered on `EntraID` and `HybridJoin`.

Accelerator-inspired enhancement:
- Broaden to enterprise identity-service patterns such as ADDS, EntraDS, EntraID, and EntraIDKerberos.
- Add Intune enrollment support where relevant.

### 3. Assignment Model

Current baseline:
- Access assignment is centered on comma-separated object IDs.
- Role assignments are effectively treated as user assignments.

Accelerator-inspired enhancement:
- Add group-based assignment.
- Add typed principal assignment model.
- Allow separate audiences for desktops and RemoteApps.

### 4. Host Pool Controls

Current baseline:
- Only a limited subset of host pool controls are user-facing.

Accelerator-inspired enhancement:
- Expose load balancing, max sessions, personal assignment type, and public access posture.
- Add scaling plan support and better Start VM on Connect UX.

### 5. Networking Options

Current baseline:
- Optimized for existing VNet selection.
- Private connectivity posture is not exposed as a broader decision model.

Accelerator-inspired enhancement:
- Add create-new-network path.
- Add private endpoints and private DNS options.
- Add public access posture controls for host pool and workspace.

### 6. RemoteApp Authoring UX

Current baseline:
- RemoteApps are authored through raw JSON input in portal experiences.

Accelerator-inspired enhancement:
- Replace JSON-only input with structured fields or a repeatable editor.
- Offer a standard app catalog for common built-ins.

### 7. Security and Operations

Current baseline:
- Monitoring and VM security are present but exposed with fewer configuration options.

Accelerator-inspired enhancement:
- Add security type selection such as Trusted Launch.
- Add monitoring presets, scaling plans, and brownfield operational helpers.

## Immediate Implementation Focus

The first implementation slice should address the most visible UX gains with the least ambiguity:
- image source selection
- group-aware assignment model
- alignment of docs, params, and template behavior
- expanded identity model surface
