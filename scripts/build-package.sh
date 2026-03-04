#!/bin/bash
# scripts/build-package.sh
# This script is invoked by the GitHub Actions workflow when a new release of
# bloa-src is detected. It downloads the release asset .deb files and updates
# the apt repository indexes, handling multiple architectures correctly.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
UPSTREAM_REPO="bloa-lang/bloa-src"
PKGNAME="bloa"

# paths inside apt-repo
POOL_DIR="$(pwd)/pool/main/b/${PKGNAME}"
DIST_DIR="$(pwd)/dists/stable/main"

mkdir -p "$POOL_DIR"

# find all .deb assets for this version on GitHub
echo "Looking for .deb assets in upstream release ${VERSION}"
release_info=$(curl -sL "https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/${VERSION}")
asset_urls=$(echo "$release_info" | jq -r '.assets[] | select(.name | test("bloa.*\\.deb$")) | .browser_download_url')

if [ -z "$asset_urls" ]; then
  echo "ERROR: no .deb assets matching pattern found for tag $VERSION" >&2
  exit 1
fi

# download all matching .deb files
echo "Downloading .deb assets..."
while IFS= read -r asset_url; do
  [ -z "$asset_url" ] && continue
  asset_name=$(basename "$asset_url")
  echo "  Downloading: $asset_name"
  curl -sL -o "$asset_name" "$asset_url"
  cp "$asset_name" "$POOL_DIR/"
  rm "$asset_name"
done <<< "$asset_urls"

# update Packages index for each architecture
echo "Regenerating package indexes for all architectures"

for arch in amd64 aarch64; do
  mkdir -p "$DIST_DIR/binary-${arch}"
  echo "Processing architecture: $arch"
  
  # create temporary directory with symlinks to matching .deb files
  tmppool=$(mktemp -d)
  trap "rm -rf '$tmppool'" EXIT
  
  # find all .deb files in pool that match this architecture
  found=0
  while IFS= read -r debfile; do
    [ -z "$debfile" ] && continue
    ln -s "$debfile" "$tmppool/$(basename "$debfile")"
    ((found++))
  done < <(find "$POOL_DIR" \( -name "*_${arch}.deb" -o -name "*_all.deb" \) | sort)
  
  if [ $found -eq 0 ]; then
    echo "  No packages found for $arch, creating empty index"
    : > "$DIST_DIR/binary-${arch}/Packages"
    gzip -9c < "$DIST_DIR/binary-${arch}/Packages" > "$DIST_DIR/binary-${arch}/Packages.gz"
  else
    echo "  Found $found package(s) for $arch"
    dpkg-scanpackages "$tmppool" /dev/null > "$DIST_DIR/binary-${arch}/Packages"
    gzip -9c < "$DIST_DIR/binary-${arch}/Packages" > "$DIST_DIR/binary-${arch}/Packages.gz"
  fi
done

echo "Package build complete."
