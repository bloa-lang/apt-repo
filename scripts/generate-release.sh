#!/usr/bin/env bash
set -euo pipefail

DIST_ROOT="${1:-.}"
DIST_NAME="${2:-stable}"
COMP="${3:-main}"

DIST_DIR="$DIST_ROOT/$COMP"
RELEASE_FILE="$DIST_ROOT/Release"

if [ ! -d "$DIST_DIR" ]; then
  echo "ERROR: $DIST_DIR not found"
  exit 1
fi

arch_list=()
md5_lines=()
sha256_lines=()

shopt -s nullglob

for binary_dir in "$DIST_DIR"/binary-*; do
  [ -d "$binary_dir" ] || continue

  arch="${binary_dir##*/}"
  arch="${arch#binary-}"
  arch_list+=("$arch")

  for file in Packages Packages.gz; do
    full="$binary_dir/$file"
    [ -f "$full" ] || continue

    rel_path="$COMP/binary-$arch/$file"
    size=$(stat -c%s "$full")

    md5=$(md5sum "$full" | awk '{print $1}')
    sha256=$(sha256sum "$full" | awk '{print $1}')

    md5_lines+=(" $md5 $size $rel_path")
    sha256_lines+=(" $sha256 $size $rel_path")
  done
done

if [ ${#arch_list[@]} -eq 0 ]; then
  echo "ERROR: No architectures detected"
  exit 1
fi

arch_str=$(IFS=' '; echo "${arch_list[*]}")
date_str=$(date -u +"%a, %d %b %Y %Y %H:%M:%S UTC")

{
  echo "Origin: bloa-lang"
  echo "Label: bloa"
  echo "Suite: $DIST_NAME"
  echo "Codename: $DIST_NAME"
  echo "Date: $date_str"
  echo "Architectures: $arch_str"
  echo "Components: $COMP"
  echo "Description: Official bloa APT repository"
  echo "MD5Sum:"
  printf "%s\n" "${md5_lines[@]}" | sort
  echo "SHA256:"
  printf "%s\n" "${sha256_lines[@]}" | sort
} > "$RELEASE_FILE"

echo "Release file generated at $RELEASE_FILE"
