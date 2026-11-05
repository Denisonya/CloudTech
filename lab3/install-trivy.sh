#!/usr/bin/env bash
set -euo pipefail

# Версия и SHA256 из официального релиза Trivy для Linux x86_64.
version=0.75.0
checksum=c6e65abddb348e25f10549df887045629cf28cc72453cd1c63acb717316b3f3f
install_dir="${1:-lab3/.tools}"
mkdir -p "$install_dir"
archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
curl --fail --location --retry 3     "https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_Linux-64bit.tar.gz"     --output "$archive"
echo "$checksum  $archive" | sha256sum --check --status
tar -xzf "$archive" -C "$install_dir" trivy
"$install_dir/trivy" --version
