#!/usr/bin/env bash
# Installs the CLI tools `gitops-ai bootstrap` needs, pinned by version and SHA-256.
set -euo pipefail

K3D_VERSION="v5.9.0"
K3D_SHA256="06d8f25bc3a971c4eb29e0ff08429b180402db0f4dec838c9eac427e296800a0"
FLUX_OPERATOR_VERSION="0.61.0"
FLUX_OPERATOR_SHA256="5720a6b38e48f950dd97cb06f692695700e0239b28503e1926cc28cf8310145c"
SOPS_VERSION="v3.13.3"
SOPS_SHA256="e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b"
AGE_VERSION="v1.3.2"
AGE_SHA256="cbe24006683f8eb669266162894b9a522a1af52f2665fbc63a4bb032ed26ac10"
# Keep in line with KUBERNETES_VERSION in gitops-ai-bootstrapper (k3s image of the cluster).
KUBECTL_VERSION="v1.35.1"
KUBECTL_SHA256="36e2f4ac66259232341dd7866952d64a958846470f6a9a6a813b9117bd965207"

if [ "$(uname -m)" != "x86_64" ]; then
  echo "post-create: checksums are pinned for linux/amd64 only (found $(uname -m))" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch() {
  local url="$1" sha256="$2" dest="$3"
  curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$dest" "$url"
  echo "${sha256}  ${dest}" | sha256sum --check --quiet -
}

fetch "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64" \
  "$K3D_SHA256" "$tmp/k3d"
sudo install -m 0755 "$tmp/k3d" /usr/local/bin/k3d

fetch "https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v${FLUX_OPERATOR_VERSION}/flux-operator_${FLUX_OPERATOR_VERSION}_linux_amd64.tar.gz" \
  "$FLUX_OPERATOR_SHA256" "$tmp/flux-operator.tar.gz"
tar -xzf "$tmp/flux-operator.tar.gz" -C "$tmp" flux-operator
sudo install -m 0755 "$tmp/flux-operator" /usr/local/bin/flux-operator

fetch "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64" \
  "$SOPS_SHA256" "$tmp/sops"
sudo install -m 0755 "$tmp/sops" /usr/local/bin/sops

fetch "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz" \
  "$AGE_SHA256" "$tmp/age.tar.gz"
tar -xzf "$tmp/age.tar.gz" -C "$tmp"
sudo install -m 0755 "$tmp/age/age" /usr/local/bin/age
sudo install -m 0755 "$tmp/age/age-keygen" /usr/local/bin/age-keygen

fetch "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  "$KUBECTL_SHA256" "$tmp/kubectl"
sudo install -m 0755 "$tmp/kubectl" /usr/local/bin/kubectl

echo "post-create: k3d ${K3D_VERSION}, flux-operator v${FLUX_OPERATOR_VERSION}, sops ${SOPS_VERSION}, age ${AGE_VERSION}, kubectl ${KUBECTL_VERSION}"
