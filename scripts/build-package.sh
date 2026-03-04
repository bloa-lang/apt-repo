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

# detect architectures by scanning .deb files in pool
arches=()
if [ -d "$POOL_DIR" ]; then
  while IFS= read -r debfile; do
    [ -z "$debfile" ] && continue
    # extract architecture from filename (format: pkg_version_ARCH.deb)
    arch=$(basename "$debfile" | sed -n 's/.*_\([^_]\+\)\.deb$/\1/p')
    # skip arch-independent packages (marked as 'all')
    [ "$arch" = "all" ] && continue
    # add to list if not already present
    if ! printf '%s\n' "${arches[@]}" 2>/dev/null | grep -q "^$arch$"; then
      arches+=("$arch")
    fi
  done < <(find "$POOL_DIR" -maxdepth 1 -type f -name "*.deb" | sort)
fi

if [ ${#arches[@]} -eq 0 ]; then
  echo "WARNING: No .deb files found in pool; using fallback architectures"
  arches=(amd64 aarch64 i386)
fi

echo "Detected architectures: ${arches[*]}"

for arch in "${arches[@]}"; do
  mkdir -p "$DIST_DIR/binary-${arch}"
  echo "Processing architecture: $arch"

  # create temporary directory with symlinks to matching .deb files
  tmppool=$(mktemp -d)

  # find all .deb files in pool that match this architecture (or arch-independent)
  found=0
  while IFS= read -r debfile; do
    [ -z "$debfile" ] && continue
    ln -s "$debfile" "$tmppool/$(basename "$debfile")"
    found=$((found+1))
  done < <(find "$POOL_DIR" -type f -name "*_${arch}.deb" -o -name "*_all.deb" | sort)

  if [ $found -eq 0 ]; then
    echo "  No packages found for $arch, creating empty index"
    : > "$DIST_DIR/binary-${arch}/Packages"
    gzip -9c < "$DIST_DIR/binary-${arch}/Packages" > "$DIST_DIR/binary-${arch}/Packages.gz"
  else
    echo "  Found $found package(s) for $arch"
    dpkg-scanpackages "$tmppool" /dev/null > "$DIST_DIR/binary-${arch}/Packages"
    gzip -9c < "$DIST_DIR/binary-${arch}/Packages" > "$DIST_DIR/binary-${arch}/Packages.gz"
  fi

  rm -rf "$tmppool"
done

echo "Generating Release file"
bash "$(dirname "$0")/generate-release.sh" "$DIST_DIR" "stable" "main"

echo "Package build complete."
