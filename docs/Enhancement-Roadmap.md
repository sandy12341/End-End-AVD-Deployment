# Enhancement Roadmap

## Purpose

This roadmap sequences the enhancement work in E2EAVDDeployment so the project can evolve from the validated baseline without losing deployability.

## Phase Order

### Phase 1: Image Source Foundation

Scope:
- Extend `infra/main.bicep` and `infra/modules/sessionhosts.bicep` with image-source parameters.
- Update both portal definitions to support marketplace and gallery selection.
- Add validation and sample parameter files.

Exit criteria:
- Baseline marketplace path still deploys successfully.
- Gallery image path validates and deploys successfully in at least one scenario.

### Phase 2: Identity and Assignment Refactor

Scope:
- Generalize assignment inputs from raw user IDs to typed principal assignments.
- Add support for groups and separate desktop versus RemoteApp audiences.
- Reconcile resolver-mode implementation with docs and parameter files.

Exit criteria:
- User assignment and group assignment both work.
- Resolver mode is either fully implemented or clearly removed from unsupported surfaces.

### Phase 3: Expanded Auth Models

Scope:
- Introduce broader identity modes aligned to enterprise AVD patterns.
- Add Intune enrollment toggle and conditional validation.
- Normalize naming so auth and identity terms are consistent.

Exit criteria:
- Entra-based and domain-based flows both validate cleanly.
- Wizard only shows relevant inputs for the selected identity mode.

### Phase 4: Host Pool UX Improvements

Scope:
- Expose load balancing, max sessions, personal assignment type, Start VM on Connect, and RDP property presets.
- Replace raw RemoteApp JSON entry with a structured authoring experience.

Exit criteria:
- Desktop, RemoteApp, and combined modes remain functional.
- Structured RemoteApp input produces the same template outputs as manual definitions.

### Phase 5: Network and Security Posture

Scope:
- Add create-new-network option.
- Add host pool and workspace public access controls.
- Add private endpoint and private DNS options.
- Add VM security type controls.

Exit criteria:
- Existing-network path still works.
- At least one private connectivity deployment path is validated.

### Phase 6: Operations and Day-2 Tooling

Scope:
- Add scaling plans and schedule UX.
- Add brownfield helper templates or scripts.
- Improve monitoring presets and deployment summaries.

Exit criteria:
- At least one brownfield scenario is documented and validated.
- Scaling plan deployment path is tested for pooled mode.

## Verification Model

For every phase:
- Run template validation for direct Bicep/ARM deployment.
- Validate both direct template and managed-app portal surfaces if affected.
- Record at least one end-to-end deployment scenario in docs.
- Keep backward-compatible defaults wherever practical.

## Repo Strategy

- Keep this repo as the active enhancement workspace.
- Treat the original AVD-Landing-Zone repo as the stable reference baseline.
- Back-port only after a feature is validated and intentionally selected for promotion.
