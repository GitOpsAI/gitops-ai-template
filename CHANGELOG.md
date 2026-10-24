# Changelog

All notable changes to this GitOps template are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### AI

- **OpenClaw**: migrated from the community Helm chart (`serhanekicii/openclaw-helm` **1.5.36**) to the [OpenClaw operator](https://github.com/paperclipinc/openclaw-operator) **0.40.0**.
  - New package [`templates/ai/openclaw-operator`](templates/ai/openclaw-operator): operator `HelmRelease` from a cosign-verified `OCIRepository` (`oci://ghcr.io/paperclipinc/charts/openclaw-operator`), namespace `openclaw-operator-system` (Pod Security `restricted`), RBAC scoped to the `openclaw-instance` namespace via `watchNamespaces`, default-deny ingress `NetworkPolicy`.
  - `templates/ai/openclaw` renamed to [`templates/ai/openclaw-instance`](templates/ai/openclaw-instance): `OpenClawInstance` `openclaw-instance` wrapped in [`helm-release-openclaw-instance.yaml`](templates/ai/openclaw-instance/helm-release-openclaw-instance.yaml) (`additional-manifests`, `dependsOn` the operator so CRDs exist first). Removed `helm-release-openclaw.yaml` and `helm-repository-openclaw.yaml`.
  - OpenClaw image bumped **2026.5.12 → 2026.10.7**. Operator 0.40.0 leaves the PVC root owned by root; 2026.9.x crash-loops on that (`EPERM ... fchmod`), while 2026.10.x logs a warning and keeps the existing mode, so no root init container is needed. Do not pin 2026.9.x.
  - Model ID updated to `openai/gpt-5.6-sol` and the retired `agents.entries.<id>.default` marker removed. 2026.10 treats both as legacy keys, and `doctor` would otherwise rewrite them on every start (merge mode re-applies the CR config).
  - Config moved to `spec.config.raw` (`mergeMode: merge`) and updated to the current schema: `agents.list` → `agents.entries`, `logging.consoleStyle: compact` → `json`; dropped `logging.redactSensitive`, hard-coded `/home/node` paths, `trustedProxies`, `controlUi.allowedOrigins` and `browser` profiles (the operator injects these).
  - Gateway token still comes from `openclaw-envs` / `OPENCLAW_GATEWAY_TOKEN` (no secret format change). The rendered ConfigMap only contains the `${OPENCLAW_GATEWAY_TOKEN}` reference.
  - Operator-managed `NetworkPolicy` is disabled in favour of [`network-policy-openclaw.yaml`](templates/ai/openclaw-instance/network-policy-openclaw.yaml): ingress on the gateway proxy port only from the Envoy proxy pods of the `public` Gateway, metrics from `victoria-metrics`; egress limited to kube-dns and public TCP 80/443 (RFC1918, link-local and CGNAT blocked).
  - Exposed through the shared Gateway with an operator-managed `HTTPRoute` (`spec.networking.httpRoute`) instead of an Ingress. `gateway.controlUiOrigins` is set explicitly because the operator derives allowed origins from Ingress hosts only.
  - Namespace renamed `openclaw` → `openclaw-instance`; it enforces Pod Security `baseline` (audit/warn `restricted`).
  - Metrics enabled (OTel collector sidecar + `ServiceMonitor`) plus the operator `PrometheusRule` (crash-loop, OOM, PVC > 80 % alerts; converted to `VMRule`). The instance now `dependsOn` `prometheus-operator-crds`.
  - All pod images are digest-pinned: OpenClaw, Chromium, OTel collector, `init-uv`, and the gateway proxy, which moves from the end-of-life operator default `nginx:1.27-alpine` to `nginx:1.30-alpine`.
  - `config.forcePaths: [gateway]`: the gateway section (auth mode, bind, trusted proxies, allowed origins) is rebuilt from Git on every restart, so changes made through the Control UI cannot persist there; other runtime changes are still merged.
  - Disk-aware readiness (`probes.diskReadiness`, `minFree: 256Mi`): a full or read-only PVC marks the pod NotReady instead of serving failing requests.
  - Rate limiting: 20 requests/s per client IP via a route-level `BackendTrafficPolicy` (Envoy local rate limit; no nginx-style 5x burst). The same policy disables the request timeout so the Control UI WebSocket is not cut after 300 s.

### System

- **Gateway API replaces ingress-nginx**: `ingress-nginx-external` is no longer part of the default components; every UI is published through a single `Gateway` ([`helm-release-enwoy-gateway-config.yaml`](templates/system/enwoy-gateway/helm-release-enwoy-gateway-config.yaml)).
  - `GatewayClass` `envoy` with an `EnvoyProxy` (`LoadBalancer`, `externalTrafficPolicy: Local` to keep client IPs) and `Gateway` `envoy-gateway-system/public`: HTTP listener redirects to HTTPS (301), HTTPS listener `*.${cluster_domain}` terminates TLS with `wildcard-${cluster_name}-tls`.
  - Routes are accepted only from `flux-system`, `grafana`, `victoria-metrics` and `openclaw-instance`; add a namespace to the listener selector when exposing another component.
  - `SecurityPolicy` `ip-allowlist`: default deny, allow `INGRESS_NGINX_ALLOWED_IPS` (comma-separated CIDRs, injected with a `postRenderers` JSON patch). Same scope as the former `whitelist-source-range` annotations; IPv6 clients are denied unless listed.
  - `ClientTrafficPolicy`: TLS 1.2 minimum and `Strict-Transport-Security: max-age=31536000; includeSubDomains`, matching the ingress-nginx defaults.
  - `BackendTrafficPolicy`: 300 s request timeout (Envoy defaults to 15 s; ingress-nginx used 300 s for the Flux UI).
  - Namespace `envoy-gateway-system` enforces Pod Security `baseline` (audit/warn `restricted`).
- **cert-manager**: one wildcard `Certificate` `*.${cluster_domain}` (DNS-01, ECDSA P-256, key rotated on renewal) in `envoy-gateway-system` replaces the per-app Ingress certificates. `cert-manager-additional-manifests` no longer waits for issuance (`disableWait`).
- **external-dns**: `gateway-httproute` source added (records for every attached `HTTPRoute` hostname, target from the Gateway's `external-dns.alpha.kubernetes.io/target` annotation); now `dependsOn` `enwoy-gateway`.
- **Flux Web UI**: chart `HTTPRoute` instead of Ingress; the chart `NetworkPolicy` (all namespaces) is replaced by [`network-policy-flux-web.yaml`](templates/system/flux-web/network-policy-flux-web.yaml), which admits only the Envoy proxies on port 9080. Without it the FluxInstance network policies blocked the UI from outside `flux-system`.
- **Grafana**: standalone `HTTPRoute` in `grafana-instance` instead of the `Grafana` CR ingress (the operator only detects Gateway API CRDs at startup, so `spec.httpRoute` would be ignored on upgraded clusters until it restarts). The operator deletes the old Ingress.
- **VictoriaMetrics**: `vmsingle`, `vmalert` and `vmagent` use the chart `route` (HTTPRoute) instead of Ingress.
- **Envoy Gateway** ([`helm-release-enwoy-gateway.yaml`](templates/system/enwoy-gateway/helm-release-enwoy-gateway.yaml)): chart and controller **v1.8.0 → v1.9.2**, pulled via an `OCIRepository` (`oci://docker.io/envoyproxy/gateway-helm`) and `chartRef`. The chart version was previously set to `1.0.0`, which does not exist in the registry.
  - Envoy proxy pinned to **`distroless-v1.39.5`** (controller default is `distroless-v1.39.1`); rate limit image moved to the v1.9.2 default **`0482748e`**. All three images are pinned by tag and digest.
  - `install.crds` / `upgrade.crds: CreateReplace`: the Gateway API and Envoy Gateway CRDs live in the chart's `crds/` directory, which Helm skips on upgrade, so Flux now updates them too.
  - Fixed yamllint errors (sequence indentation, missing newline at end of file).

### Migration

- The old Helm release is uninstalled when Flux prunes it, and its PVC `openclaw/openclaw-data` is **deleted with it**. To keep agent state (sessions, memory, Codex OAuth tokens, workspace), back up `/home/node/.openclaw` before syncing this version. Then restore it into the new pod: `kubectl cp` into `openclaw-instance/openclaw-instance-0`, container `openclaw`, path `/home/openclaw/.openclaw`.
- Namespace changed `openclaw` → `openclaw-instance`. In existing cluster repos, update `metadata.namespace` of the SOPS-encrypted `clusters/<name>/components/openclaw/secret-openclaw-envs.yaml` (`sops edit`); Flux prunes the old `openclaw` namespace.
- Workload names changed: `openclaw/deployment/openclaw` (container `main`) → `openclaw-instance/statefulset/openclaw-instance` (container `openclaw`). Update any scripts that exec into the pod, for example `kubectl exec -n openclaw-instance openclaw-instance-0 -c openclaw -- openclaw devices list`.
- Devices must be paired again after migration.
- Ingresses are removed and Flux prunes `ingress-nginx-external`. Until the wildcard certificate is issued (check `kubectl get certificate -n envoy-gateway-system`), HTTPS serves no certificate. The old per-app TLS Secrets (`flux-*-tls`, `grafana-*-tls`, `victoria-*-tls`, `openclaw-tls`) are no longer used and can be deleted.
- Custom manifests that still use `ingressClassName: nginx-external` (MinIO, Home Assistant, Headlamp, LiteLLM, n8n templates) have no controller after the upgrade; move them to an `HTTPRoute` on `envoy-gateway-system/public` or re-add `ingress-nginx-external` to `components/kustomization.yaml`.

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
