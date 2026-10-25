# Changelog

All notable changes to this GitOps template are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.2.0] — 2026-10-25

### Migration (action required)

- **Back up OpenClaw first.** Flux deletes the old release **and its PVC** `openclaw/openclaw-data` (sessions, memory, Codex OAuth tokens, workspace). Copy out `/home/node/.openclaw` before syncing, then `kubectl cp` it to `openclaw-instance/openclaw-instance-0`, container `openclaw`, path `/home/openclaw/.openclaw`.
- **Move the OpenClaw secret:** `sops edit clusters/<name>/components/openclaw/secret-openclaw-envs.yaml` and set `metadata.namespace: openclaw-instance`.
- **Update scripts that exec into OpenClaw:** `deployment/openclaw` (container `main`) is now `statefulset/openclaw-instance` (container `openclaw`), e.g. `kubectl exec -n openclaw-instance openclaw-instance-0 -c openclaw -- openclaw devices list`. Pair devices again.
- **Expect a short outage on ports 80/443:** the Envoy proxy Service is renamed to `envoy-public`, so Envoy Gateway creates a new `LoadBalancer` Service and deletes the old one.
- **HTTPS is down until the wildcard certificate is issued** (`kubectl get certificate -n envoy-gateway-system`). The old per-app TLS secrets (`flux-*-tls`, `grafana-*-tls`, `victoria-*-tls`, `openclaw-tls`) can be deleted.
- **Custom Ingresses stop working** (`ingressClassName: nginx-external`: MinIO, Home Assistant, Headlamp, LiteLLM, n8n). Move them to an `HTTPRoute` on `envoy-gateway-system/public`, or re-add `ingress-nginx-external` to `components/kustomization.yaml`.

### AI: OpenClaw runs on the operator

- Community Helm chart replaced by the [OpenClaw operator](https://github.com/paperclipinc/openclaw-operator) **0.40.0** ([`openclaw-operator`](templates/ai/openclaw-operator): cosign-verified OCI chart, RBAC limited to `openclaw-instance`).
- `templates/ai/openclaw` is now [`openclaw-instance`](templates/ai/openclaw-instance): one `OpenClawInstance` in namespace `openclaw-instance` (Pod Security `baseline`, audit/warn `restricted`).
- Image **2026.5.12 → 2026.10.7**, model `openai/gpt-5.6-sol`. Do not pin 2026.9.x: it crash-loops on the root-owned PVC.
- Config lives in `spec.config.raw` (merge mode, current schema). The `gateway` section is rebuilt from Git on every restart; the gateway token still comes from `openclaw-envs`.
- Published through an operator-managed `HTTPRoute`: 20 req/s per client IP, no request timeout so the Control UI WebSocket stays open.
- Own `NetworkPolicy`: ingress only from the Gateway proxies and metrics scraping; egress only DNS and public 80/443.
- Metrics and alerts (crash-loop, OOM, PVC > 80 %), disk-aware readiness, every image digest-pinned (gateway proxy now `nginx:1.30-alpine`).

### System: Gateway API replaces ingress-nginx

- One `Gateway` (`envoy-gateway-system/public`) serves every UI: HTTP redirects to HTTPS, one wildcard certificate `*.${cluster_domain}` (cert-manager DNS-01, ECDSA P-256).
- Same protections as before: IP allowlist from `INGRESS_NGINX_ALLOWED_IPS` (IPv6 denied unless listed), TLS 1.2+, HSTS, 300 s request timeout.
- Routes are accepted only from `flux-system`, `grafana`, `victoria-metrics` and `openclaw-instance`; add a namespace to the listener selector to expose another app.
- Flux Web, Grafana and VictoriaMetrics use `HTTPRoute`s instead of Ingresses; Flux Web gets its own `NetworkPolicy` (Envoy proxies only). external-dns now creates records from `HTTPRoute`s.
- Envoy Gateway **v1.8.0 → v1.9.2** from an OCI chart (CRDs now updated on upgrade), proxy `distroless-v1.39.5`, all images digest-pinned.
- The Envoy proxy Service has a fixed name, `envoy-public`. Only one Gateway may use this `EnvoyProxy`.
- cert-manager: set `letsencrypt_server` in `cluster-sync.yaml` to point both `ClusterIssuer`s at another ACME server (e.g. Let's Encrypt staging). The default stays production.

### System: Cloudflare Tunnel (opt-in)

- New package [`cloudflare-tunnel`](templates/system/cloudflare-tunnel): `cloudflared` **2026.10.3** (tag + digest), 2 replicas with a `PodDisruptionBudget`.
- Hardened pod: Pod Security `restricted`, non-root (UID 65532), read-only root filesystem, all capabilities dropped, no service account token.
- Own `NetworkPolicy`: egress only DNS, the `public` Gateway's Envoy proxies (port 10443) and public IPs on 7844 TCP/UDP; ingress only metrics scraping from `victoria-metrics`.
- Off by default: the [cluster component](clusters/_template/components/cloudflare-tunnel) is not in `components/kustomization.yaml`; gitops-ai **1.4.0+** adds it when you choose Cloudflare Tunnel mode.
- End-to-end TLS: `*.${cluster_domain}` is forwarded to `envoy-public` over HTTPS with the wildcard certificate (`matchSNItoHost`), and cloudflared rejects requests without a valid Cloudflare Access token (`access.required`).
- Config changes restart the pods automatically (hashed ConfigMap); tunnel credentials are a SOPS secret.

### Developer: Codespaces

- New [`.devcontainer`](.devcontainer): Ubuntu 24.04, Docker-in-Docker and Node features pinned by digest; needs 4 CPU, 16 GB RAM, 32 GB disk. Codespaces secrets are declared and automatic port forwarding is off.
- On create, installs k3d, flux-operator, sops, age and kubectl, each pinned by version and verified by SHA-256.
- On start, restores the age key from the `SOPS_AGE_KEY` secret and restarts stopped k3d clusters.
- CI: kubeconform also validates the opt-in components.

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
