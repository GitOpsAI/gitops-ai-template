# Template synchronization

Your GitOps repository is a **fork** of this template. Flux watches **your** repo only; nothing pulls automatically from upstream. Use Git remotes and merge requests to bring in fixes and features safely.

## Upstream remote

Add the canonical template as `upstream` (HTTPS example):

```bash
git remote add upstream https://gitlab.com/everythings-gonna-be-alright/fluxcd_ai_template.git
git fetch upstream --tags
```

Use your organization’s fork path if you mirror the template elsewhere.

## Merge order (recommended)

1. **`infrastructure/base/`** — Merge first. These shared bases (HelmReleases, repos, namespaces) are the usual target for security patches and chart bumps.
2. **`clusters/_default-template/`** — Refresh the reference snapshot so “add component later” matches current layout (see the published **gitops-ai** bootstrapper docs for post-bootstrap component copy steps).
3. **`clusters/<clusterName>/`** — Merge last, or apply **selective** updates (per-component directories). This overlay contains live values, optional components, and **SOPS-encrypted secrets** — **never** overwrite wholesale from upstream.

## CI validation parity

Before merging to your default branch, mirror what this repo’s pipeline runs:

| Check                                  | Purpose                           |
|----------------------------------------|-----------------------------------|
| `yamllint`                             | YAML style and basic errors       |
| `flux build kustomization … --dry-run` | Flux can render your cluster path |
| `kubeconform`                          | API shapes and CRDs               |
| `gitleaks`                             | No plaintext secrets              |

Replicate the same `CLUSTER_*` substitutions your CI uses (see [.gitlab-ci.yml](../.gitlab-ci.yml) `CLUSTER_NAME`, etc.) when validating locally.

## Version metadata

- Root [`template-sync-metadata.yaml`](../template-sync-metadata.yaml) — current template semver and upstream coordinates.
- [`CHANGELOG.md`](../CHANGELOG.md) — release notes and breaking changes.

After merging upstream, update or confirm `template-sync-metadata.yaml` / `TEMPLATE_SYNC.md` in **your** repo to record the upstream tag you integrated.

## Automation

Use **merge requests** for every sync. Optionally run `gitops-ai template sync` from the [GitOps AI bootstrapper](https://www.npmjs.com/package/gitops-ai) to fetch and merge a tagged release with a consistent workflow.
