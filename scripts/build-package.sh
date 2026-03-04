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

# download source tarball for the version
TARBALL_URL="https://github.com/${UPSTREAM_REPO}/archive/refs/tags/${VERSION}.tar.gz"
SRC_ARCHIVE="${PKGNAME}-${VERSION}.tar.gz"

echo "Downloading upstream source: $TARBALL_URL"
curl -sL -o "$SRC_ARCHIVE" "$TARBALL_URL"

# extract, build package
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "Extracting source into $WORKDIR"
tar -xzf "$SRC_ARCHIVE" -C "$WORKDIR"
cd "$WORKDIR/${PKGNAME}-${VERSION#v}" || exit 1

# In a real project you'd run the build commands here; for this example we
# just create a dummy control file and a trivial binary to package.

echo "Creating Debian packaging tree"
mkdir -p debian
cat > debian/control <<'EOF'
Source: ${PKGNAME}
Section: misc
Priority: optional
Maintainer: APT Repo <no-reply@example.com>
Standards-Version: 4.5.0

Package: ${PKGNAME}
Architecture: any
Depends: 
Description: Dummy package for bloa-src version ${VERSION}
 A placeholder package built by the apt-repo automation.
EOF

# build package using dpkg-deb
mkdir -p usr/bin
cat > usr/bin/${PKGNAME} <<'EOF'
#!/bin/bash
echo "This is a dummy bloa-src package version ${VERSION}"
EOF
chmod +x usr/bin/${PKGNAME}

PKGFILE="${PKGNAME}_${VERSION#v}_amd64.deb"
echo "Building .deb package: $PKGFILE"
dpkg-deb --build . "$PKGFILE"

# move package into pool
mv "$PKGFILE" "$POOL_DIR/"

# update Packages index for each architecture
for arch in amd64 aarch64; do
  mkdir -p "$DIST_DIR/binary-${arch}"
  echo "Scanning packages for architecture $arch"
  dpkg-scanpackages "$POOL_DIR" /dev/null | gzip -9c > "$DIST_DIR/binary-${arch}/Packages.gz"
  # also write uncompressed for human inspection
  dpkg-scanpackages "$POOL_DIR" /dev/null > "$DIST_DIR/binary-${arch}/Packages"
done

echo "Package build complete."
