#!/bin/bash
# scripts/build-package.sh
# This script is invoked by the GitHub Actions workflow when a new release of
# bloa-src is detected. It downloads the release tarball, builds a Debian
# package, and updates the apt repository indexes.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
UPSTREAM_REPO="bloa-lang/bloa-src"
PKGNAME="bloa-src"

# paths inside apt-repo
POOL_DIR="$(pwd)/pool/main/b/${PKGNAME}"
DIST_DIR="$(pwd)/dists/stable/main"

mkdir -p "$POOL_DIR"

# find .deb asset for the version on GitHub

echo "Looking for .deb asset in upstream release ${VERSION}"
release_info=$(curl -sL "https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/${VERSION}")
asset_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | test("bloa.*\\.deb$")) | .browser_download_url' | head -n1)

if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
  echo "ERROR: no .deb asset matching pattern found for tag $VERSION" >&2
  exit 1
fi

asset_name=$(basename "$asset_url")
echo "Downloading asset $asset_name"
curl -sL -o "$asset_name" "$asset_url"

# copy into pool
cp "$asset_name" "$POOL_DIR/"

# optionally rename to uniform scheme
# you could uncomment below if you want predictable filenames
# newname="${PKGNAME}_${VERSION#v}_${asset_name##*_}"
# mv "$POOL_DIR/$asset_name" "$POOL_DIR/$newname"


# update Packages index for each architecture
for arch in amd64 aarch64; do
  mkdir -p "$DIST_DIR/binary-${arch}"
  echo "Scanning packages for architecture $arch"
  dpkg-scanpackages "$POOL_DIR" /dev/null | gzip -9c > "$DIST_DIR/binary-${arch}/Packages.gz"
  # also write uncompressed for human inspection
  dpkg-scanpackages "$POOL_DIR" /dev/null > "$DIST_DIR/binary-${arch}/Packages"
done

echo "Package build complete."
