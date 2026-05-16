# Changelog

All notable changes to this GitOps template are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.1.1] — 2026-05-10

### AI

- **OpenClaw** ([`helm-release-openclaw.yaml`](templates/ai/openclaw/helm-release-openclaw.yaml)): chart updated from **1.5.7** to **1.5.35**; `openclawVersion` bumped **2026.3.24 → 2026.5.7**; Chromium sidecar bumped **147.0.7727.24 → 148.0.7778.97**.

### Dashboards

- **Headlamp** ([`helm-release-headlamp.yaml`](templates/dashboards/headlamp/helm-release-headlamp.yaml)): chart updated from **0.41.0** to **0.42.0**.

### Homelab

- **Home Assistant** ([`helm-release-home-assistant.yaml`](templates/homelab/home-assistant/helm-release-home-assistant.yaml)): chart updated from **0.3.49** to **0.3.57**.

### Monitoring

- **Grafana instance** ([`helm-release-grafana-instance.yaml`](templates/monitoring/grafana-operator/helm-release-grafana-instance.yaml)): Grafana `spec.version` updated from **12.4.2** to **13.0.1**.
- **Victoria Metrics k8s stack** ([`helm-release-victoria-metrics-stack.yaml`](templates/monitoring/victoria-metrics-k8s-stack/helm-release-victoria-metrics-stack.yaml)): chart updated from **0.72.6** to **0.77.0**.
- **Victoria Metrics**: CRD cleanup image changed from `rancher/kubectl` to `registry.k8s.io/kubectl` (official upstream registry).
- **Victoria Metrics**: added `admissionWebhooks.policy: Ignore` to prevent races during install/upgrade.
- **Victoria Metrics**: Alertmanager upgraded **v0.28.1 → v0.32.1**; config restructured with explicit `route`/`receivers` blocks and a safe `blackhole` default receiver; `monzoTemplate` enabled; custom inline templates removed.
- **Victoria Metrics**: enabled scraping for `kubeControllerManager`, `kubeEtcd`, and `kubeScheduler`.

### System

- **cert-manager** ([`helm-release-cert-manager.yaml`](templates/system/cert-manager/helm-release-cert-manager.yaml)): chart updated from **1.20.1** to **1.20.2**.
- **external-dns** ([`helm-release-external-dns.yaml`](templates/system/external-dns/helm-release-external-dns.yaml)): pinned chart version to **1.21.1** (previously unversioned).

---

## [1.1.0] — 2026-04-11

### Monitoring

- **Prometheus Operator CRDs** ([`helm-release-prometheus-operator-crds.yaml`](templates/monitoring/prometheus-operator-crds/helm-release-prometheus-operator-crds.yaml)): chart updated from **13.0.2** to **28.0.1**.
- **Victoria Metrics k8s stack** ([`helm-release-victoria-metrics-stack.yaml`](templates/monitoring/victoria-metrics-k8s-stack/helm-release-victoria-metrics-stack.yaml)): chart updated from **0.72.2** to **0.72.6** ([upstream changelog for 0.72.6](https://docs.victoriametrics.com/helm/victoria-metrics-k8s-stack/changelog/#id-0726)).
- **Grafana instance** ([`helm-release-grafana-instance.yaml`](templates/monitoring/grafana-operator/helm-release-grafana-instance.yaml)): Grafana Operator `Grafana` CR `spec.version` updated from **12.3.0** to **12.4.2**.

### Dashboards

- **Headlamp** ([`helm-release-headlamp.yaml`](templates/dashboards/headlamp/helm-release-headlamp.yaml)): chart updated from **0.40.1** to **0.41.0**.

## [1.0.0] — 2026-04-03

### Added

- Initial semver baseline and `template-sync-metadata.yaml` for template identity and upstream sync tooling.
- Documentation for [template synchronization](docs/template-sync.md) and [major-version migrations](docs/migrations/README.md).

### Migration

- No prior numbered release; first tag should be `v1.0.0` aligned with `template-sync-metadata.yaml` `version`.
