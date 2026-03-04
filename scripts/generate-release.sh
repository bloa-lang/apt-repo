#!/bin/bash
# scripts/generate-release.sh
# Generate Release file for the apt repository

set -euo pipefail

DIST_DIR="${1:-.}"
DIST_NAME="${2:-stable}"
COMP="${3:-main}"

if [ ! -d "$DIST_DIR" ]; then
  echo "ERROR: Distribution directory $DIST_DIR not found" >&2
  exit 1
fi

# compute hashes for all Packages files
declare -A sha256sums
declare -A sha1sums
declare -A md5sums

arch_list=()
for binary_dir in "$DIST_DIR"/binary-*; do
  [ -d "$binary_dir" ] || continue
  arch=$(basename "$binary_dir" | sed 's/^binary-//')
  arch_list+=("$arch")
  
  packages_file="$binary_dir/Packages"
  packages_gz="$packages_file.gz"
  
  if [ -f "$packages_file" ]; then
    size=$(stat -f%z "$packages_file" 2>/dev/null || stat -c%s "$packages_file" 2>/dev/null || echo 0)
    md5=$(md5sum "$packages_file" | awk '{print $1}')
    sha1=$(sha1sum "$packages_file" | awk '{print $1}')
    sha256=$(sha256sum "$packages_file" | awk '{print $1}')
    
    md5sums["$arch"]="$md5 $size $COMP/binary-$arch/Packages"
    sha1sums["$arch"]="$sha1 $size $COMP/binary-$arch/Packages"
    sha256sums["$arch"]="$sha256 $size $COMP/binary-$arch/Packages"
  fi
  
  if [ -f "$packages_gz" ]; then
    size=$(stat -f%z "$packages_gz" 2>/dev/null || stat -c%s "$packages_gz" 2>/dev/null || echo 0)
    md5=$(md5sum "$packages_gz" | awk '{print $1}')
    sha1=$(sha1sum "$packages_gz" | awk '{print $1}')
    sha256=$(sha256sum "$packages_gz" | awk '{print $1}')
    
    md5sums["$arch+gz"]="$md5 $size $COMP/binary-$arch/Packages.gz"
    sha1sums["$arch+gz"]="$sha1 $size $COMP/binary-$arch/Packages.gz"
    sha256sums["$arch+gz"]="$sha256 $size $COMP/binary-$arch/Packages.gz"
  fi
done

# generate Release file
release_file="$DIST_DIR/Release"
date_str=$(date -u +'%a, %d %b %Y %H:%M:%S %Z')
arch_str=$(IFS=' '; echo "${arch_list[*]}")

{
  echo "Origin: bloa-lang"
  echo "Label: bloa-src"
  echo "Suite: $DIST_NAME"
  echo "Version: 1.0"
  echo "Codename: $DIST_NAME"
  echo "Date: $date_str"
  echo "Architectures: $arch_str"
  echo "Components: $COMP"
  echo "Description: Official bloa-src APT repository $DIST_NAME release"
  echo "MD5Sum:"
  for k in "${!md5sums[@]}"; do
    echo " ${md5sums[$k]}"
  done
  echo "SHA1:"
  for k in "${!sha1sums[@]}"; do
    echo " ${sha1sums[$k]}"
  done
  echo "SHA256:"
  for k in "${!sha256sums[@]}"; do
    echo " ${sha256sums[$k]}"
  done
} > "$release_file"

echo "Generated Release file: $release_file"
