# GitOps AI template — Flux CD 2 composition

This repository is a **Flux CD 2.x** GitOps template. It separates **reusable workload packages** from **per-cluster composition** and uses **Kustomize**, **Helm** (via Flux’s Helm controller), and **SOPS** for secrets.

## High-level architecture

1. **Flux installation** — A `FluxInstance` ([`flux-instance.yaml`](flux-instance.yaml)) pins the **Flux 2.x** distribution, enables core controllers (source, kustomize, helm, notification), and turns on **NetworkPolicy** for Flux’s own namespace. Git sync is declared to apply the path `clusters/${CLUSTER_NAME}` from your Git repository.
2. **Cluster root** — Each cluster directory (see [`clusters/_template/`](clusters/_template/)) is a Kustomize package whose only resource is the **`cluster-components`** Flux `Kustomization`.
3. **Workload bundle** — That Flux `Kustomization` reconciles `./clusters/<cluster-name>/components`: shared charts, ingress, certificates, DNS, monitoring, and optional apps. It **prunes** removed objects and decrypts **SOPS**-encrypted files using the `sops-age` secret.

So: **GitRepository → (bootstrap applies) `clusters/<name>` → Flux `Kustomization` → `clusters/<name>/components` → merged manifests** (templates + cluster secrets).

## Directory layout (rules)

| Area                                                                          | Role                                                                                                                                                                                                                                                                                            |
|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`flux-instance.yaml`](flux-instance.yaml)                                    | Declarative Flux 2 install and Git sync path; uses placeholders for repo URL, branch, and cluster name.                                                                                                                                                                                         |
| [`clusters/_template/`](clusters/_template/)                                  | **Skeleton** for a new cluster: copy to `clusters/<your-cluster>/` and replace template values.                                                                                                                                                                                                 |
| [`clusters/<name>/kustomization.yaml`](clusters/_template/kustomization.yaml) | Kubernetes **Kustomization** that lists only [`cluster-sync.yaml`](clusters/_template/cluster-sync.yaml) (the Flux `Kustomization` manifest).                                                                                                                                                   |
| [`clusters/<name>/components/`](clusters/_template/components/)               | **Composition layer**: small Kustomize packages that **include** pieces from `templates/` and add **cluster-only** resources (for example SOPS secrets). Order and dependencies are controlled by the root [`components/kustomization.yaml`](clusters/_template/components/kustomization.yaml). |
| [`templates/`](templates/)                                                    | **Reusable** Kustomize packages (namespaces, `HelmRepository`, `HelmRelease`, extra manifests). **Do not** put environment-specific secrets here; keep them under `clusters/.../components/`.                                                                                                   |

## Flux `Kustomization`: `cluster-components`

[`clusters/_template/cluster-sync.yaml`](clusters/_template/cluster-sync.yaml) defines the main Flux `Kustomization`:

- **Path**: `./clusters/${CLUSTER_NAME}/components`
- **Prune**: `true` (removed Git objects are removed from the cluster)
- **Decryption**: SOPS with `secretRef.name: sops-age`
- **Post-build substitution** (`postBuild.substitute`): replaces tokens in rendered YAML before apply. Keys are fixed and must match what you use in manifests (for example `${cluster_domain}` in Helm values).

Substituted keys in this template include: `cluster_name`, `cluster_domain`, `cluster_public_ip`, `letsencrypt_email`, `ingress_nginx_allowed_ips`. **Render** this file with `envsubst` (or your bootstrap tooling) so `${CLUSTER_NAME}` and related placeholders in the **Flux `Kustomization` spec** itself are resolved; Helm values and other YAML often use the **`postBuild`** keys (for example `${cluster_domain}`) without a shell `envsubst` step.

## Templates: how to structure a package

Under `templates/`, group workloads by concern (`system/`, `monitoring/`, `dashboards/`, `storage/`, `ai/`, `homelab/`, etc.). A typical app folder contains:

- `kustomization.yaml` — lists resources; sets `namespace:` when the app runs in a dedicated namespace.
- `namespace.yaml` — when the workload needs its own namespace.
- `helm-repository-*.yaml` — `HelmRepository` in the same namespace as the `HelmRelease` (or `flux-system` for shared repos—follow existing patterns in that subtree).
- `helm-release-*.yaml` — `HelmRelease` with `apiVersion: helm.toolkit.fluxcd.io/v2`, pinned chart `version`, and `interval` for reconciliation.

Reference [`kustomizeconfig.yaml`](kustomizeconfig.yaml) from template kustomizations that need Kustomize to **rewrite** `spec.valuesFrom` names when you use `namePrefix`/`nameSuffix` (HelmRelease → ConfigMap/Secret name references).

**Sources**: Prefer `HelmRepository` for Helm charts. Some bundles use **`OCIRepository`** for OCI-hosted charts (for example [`templates/system/flux-web/oci-repository.yaml`](templates/system/flux-web/oci-repository.yaml)).

## Cluster components: composition rules

- **One folder per concern** under `clusters/<name>/components/<component>/`, with a `kustomization.yaml` that:
  - **`resources:`** includes the path to the matching **`templates/...`** package (relative path like `../../../../templates/system/cert-manager`).
  - Adds **cluster-specific** files next to it (for example `secret-cloudflare.yaml`, `secret-openclaw-envs.yaml`) — these should be **SOPS-encrypted** in real repos, not plain secrets.
- **Do not** fork entire `templates/` into a cluster dir for small tweaks; extend via patches or extra manifests in `components/` so upstream template updates stay mergeable.

The **order** of entries in [`clusters/_template/components/kustomization.yaml`](clusters/_template/components/kustomization.yaml) matters: shared Helm repos and CRDs are listed before components that depend on them (for example Prometheus Operator CRDs before stacks that assume those CRDs exist).

## Security conventions

- **Secrets**: Store provider API tokens and similar data as **SOPS**-encrypted manifests under `clusters/.../components/`, referenced by `decryption` in the Flux `Kustomization`. Do not commit raw credentials.
- **Flux**: The template enables **network policies** on the Flux installation via `FluxInstance` (`networkPolicy: true`). Keep Flux and Helm release namespaces aligned with least-privilege RBAC from upstream charts.
- **Helm**: Pin chart versions in `HelmRelease` specs; use explicit `interval` and chart `version` fields suitable for your change cadence.

## Versioning and metadata

- [`template-sync-metadata.yaml`](template-sync-metadata.yaml) holds the template **semver** and upstream pointer; bump it when you cut releases, in line with [`CHANGELOG.md`](CHANGELOG.md) and git tags.

## CI expectations

Pipelines (for example [`.gitlab-ci.yml`](.gitlab-ci.yml) and [`.github/workflows/ci.yml`](.github/workflows/ci.yml)) **copy** `clusters/_template` to a temporary cluster name, **`envsubst`** `cluster-sync.yaml`, then run **`flux build kustomization`** and **`kubeconform`** against the built manifests. Changes that break Kustomize layout or Flux API shapes should fail CI.

## Adding a new workload (checklist)

1. Add a reusable package under `templates/<area>/<app>/` (namespace, repos, `HelmRelease`, optional extra YAML).
2. Add `clusters/_template/components/<app>/kustomization.yaml` that references the template and any optional secrets.
3. Append the new component to `clusters/_template/components/kustomization.yaml` in the **correct dependency order**.
4. Use `postBuild` variable names already wired in `cluster-sync.yaml`, or extend that file’s `substitute` map consistently and document new keys.
5. Run the same **build + kubeconform** flow locally or rely on CI.

---

This README describes the **composition rules** encoded in this repo. For Flux’s own behavior (APIs, health checks, dependencies), refer to the [Flux documentation](https://fluxcd.io/flux/) for your pinned Flux 2 version.
