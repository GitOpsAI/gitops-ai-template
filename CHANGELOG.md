# Changelog

All notable changes to this GitOps template are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.1.0] — 2026-04-11

### Monitoring

- **Prometheus Operator CRDs** ([`helm-release-prometheus-operator-crds.yaml`](templates/monitoring/prometheus-operator-crds/helm-release-prometheus-operator-crds.yaml)): chart updated from **13.0.2** to **28.0.1**.
- **Victoria Metrics k8s stack** ([`helm-release-victoria-metrics-stack.yaml`](templates/monitoring/victoria-metrics-k8s-stack/helm-release-victoria-metrics-stack.yaml)): chart updated from **0.72.2** to **0.72.6** ([upstream changelog for 0.72.6](https://docs.victoriametrics.com/helm/victoria-metrics-k8s-stack/changelog/#id-0726)).

## [1.0.0] — 2026-04-03

### Added

- Initial semver baseline and `template-sync-metadata.yaml` for template identity and upstream sync tooling.
- Documentation for [template synchronization](docs/template-sync.md) and [major-version migrations](docs/migrations/README.md).

### Migration

- No prior numbered release; first tag should be `v1.0.0` aligned with `template-sync-metadata.yaml` `version`.
