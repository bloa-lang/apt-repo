#!/usr/bin/env bash
set -euo pipefail

[[ $# -ne 1 ]] && { echo "Usage: $0 <version>"; exit 1; }

VERSION="$1"
UPSTREAM_REPO="bloa-lang/bloa-src"
PKGNAME="bloa"
REPO_ROOT="$(git rev-parse --show-toplevel)"
POOL_DIR="$REPO_ROOT/pool/main/b/${PKGNAME}"
DIST_ROOT="$REPO_ROOT/dists/stable"
DIST_DIR="$DIST_ROOT/main"

rm -rf "$POOL_DIR" && mkdir -p "$POOL_DIR"

asset_urls=$(curl -sL "https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/${VERSION}" | jq -r '.assets[] | select(.name | test("\\.deb$")) | .browser_download_url')

for url in $asset_urls; do
  curl -sL -o "$POOL_DIR/$(basename "$url")" "$url"
done

mapfile -t arches < <(find "$POOL_DIR" -name "*.deb" | sed -n 's/.*_\([^_]\+\)\.deb$/\1/p' | sort -u)
arches+=("all")

cd "$REPO_ROOT"
for arch in "${arches[@]}"; do
  BIN_PATH="$DIST_DIR/binary-$arch"
  mkdir -p "$BIN_PATH"
  dpkg-scanpackages --arch "$arch" pool /dev/null > "$BIN_PATH/Packages"
  gzip -9c "$BIN_PATH/Packages" > "$BIN_PATH/Packages.gz"
done

bash "$(dirname "$0")/generate-release.sh" "$DIST_ROOT" "stable" "main"

echo "APT repository for $PKGNAME version $VERSION updated successfully."
