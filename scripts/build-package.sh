#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
UPSTREAM_REPO="bloa-lang/bloa-src"
PKGNAME="bloa"

REPO_ROOT="$(git rev-parse --show-toplevel)"
POOL_DIR="$REPO_ROOT/pool/main/b/${PKGNAME}"
DIST_ROOT="$REPO_ROOT/dists/stable"
DIST_DIR="$DIST_ROOT/main"

echo "Cleaning old pool directory..."
rm -rf "$POOL_DIR"
mkdir -p "$POOL_DIR"

echo "Fetching release metadata for $VERSION"
release_json=$(curl -sL "https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/${VERSION}")

asset_urls=$(echo "$release_json" | jq -r '.assets[] | select(.name | test("\\.deb$")) | .browser_download_url')

if [ -z "$asset_urls" ]; then
  echo "ERROR: No .deb assets found for tag $VERSION"
  exit 1
fi

echo "Downloading assets..."
while IFS= read -r url; do
  [ -z "$url" ] && continue
  name=$(basename "$url")
  echo "  → $name"
  curl -sL -o "$POOL_DIR/$name" "$url"
done <<< "$asset_urls"

echo "Detecting architectures..."
mapfile -t arches < <(
  find "$POOL_DIR" -type f -name "*.deb" \
  | sed -n 's/.*_\([^_]\+\)\.deb$/\1/p' \
  | sort -u
)

[ ${#arches[@]} -eq 0 ] && arches=("aarch64")

echo "Architectures detected: ${arches[*]}"

for arch in "${arches[@]}"; do
  mkdir -p "$DIST_DIR/binary-$arch"

  echo "Generating Packages index for $arch"

  pushd "$REPO_ROOT" >/dev/null

  dpkg-scanpackages -a "$arch" pool /dev/null \
    > "$DIST_DIR/binary-$arch/Packages"

  popd >/dev/null

  gzip -9c "$DIST_DIR/binary-$arch/Packages" \
    > "$DIST_DIR/binary-$arch/Packages.gz"
done

echo "Ensuring binary-all exists..."
mkdir -p "$DIST_DIR/binary-all"
dpkg-scanpackages -a all "$POOL_DIR" /dev/null \
  > "$DIST_DIR/binary-all/Packages" || true

gzip -9c "$DIST_DIR/binary-all/Packages" \
  > "$DIST_DIR/binary-all/Packages.gz"

echo "Generating Release file"
bash "$(dirname "$0")/generate-release.sh" "$DIST_ROOT" "stable" "main"

echo "APT repository for $PKGNAME version $VERSION updated successfully."
