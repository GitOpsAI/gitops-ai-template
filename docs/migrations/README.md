# Major-version migrations

Breaking changes are announced in the root [CHANGELOG.md](../../CHANGELOG.md) and summarized here by major line.

| Major | Status | Notes |
|-------|--------|--------|
| **v1** | Current | Baseline; no migrations before `v1.0.0`. |

## How to upgrade across majors

1. Read the **CHANGELOG** section for the target release (especially **Changed** / **Removed**).
2. Merge or sync from the upstream template tag (see [Template synchronization](../template-sync.md)).
3. Reconcile `clusters/<your-cluster>/` with the updated `clusters/_default-template/` (three-way merge or component-level copy — never blindly overwrite encrypted secrets or local tweaks).
4. Run the same validation as CI: `flux build kustomization`, kubeconform, yamllint.
5. Apply to a **staging** cluster or **suspend** risky Flux `Kustomization` / `HelmRelease` resources until smoke tests pass.
