## Upstream template sync

<!-- Describe which upstream tag or commit you merged (e.g. `v1.0.0`). -->

### Checklist

- [ ] Read [CHANGELOG.md](CHANGELOG.md) for breaking changes.
- [ ] Merged `infrastructure/base/` and reconciled conflicts.
- [ ] Refreshed `clusters/_default-template/` if needed.
- [ ] Updated `clusters/<name>/` selectively (no blind overwrite of secrets or local tweaks).
- [ ] Ran local validation: `flux build` + kubeconform (same as CI).
- [ ] Updated `TEMPLATE_SYNC.md` / `metadata.yaml` in **this** repo to record upstream ref.

### Risk note

- **Low-touch:** changes only under `infrastructure/base/` are often routine (still run CI).
- **High-touch:** edits to `flux-instance-values.yaml`, `.sops.yaml`, or `**/secret-*.yaml` need extra review before merge.

See [docs/template-sync.md](docs/template-sync.md).
