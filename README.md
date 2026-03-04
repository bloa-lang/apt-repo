# apt-repo

This repository holds an apt archive for the `bloa-src` project.  
The built packages live under `pool/` and distribution indexes under `dists/`.

## Automation

A GitHub Actions workflow (`.github/workflows/release-watch.yml`) periodically polls the
`bloa-lang/bloa-src` repository for new releases. When a new tag is detected the
workflow:

1. Downloads the source tarball for the release.
2. Builds a Debian package (`.deb`) via `dpkg-deb` (the script can be extended to
   run a real build).
3. Places the generated package in `pool/main/bloa-src/`.
4. Re-scans the pool and updates `dists/stable/main/binary-{amd64,aarch64}` indexes.
5. Commits the new files and pushes them back to this repository.

The logic lives primarily in `scripts/build-package.sh`, which is executed by the
workflow whenever a version change is observed.  The workflow triggers on a
periodic schedule and can be run manually via `workflow_dispatch`.

The file `.latest_release` records the most recent tag seen, so even if the
workflow runs multiple times without a new release, it will be a no-op.

### Adding or modifying architecture support

The build script loops over a hard-coded list `amd64`/`aarch64`; update it for
additional architectures as needed.  When saving packages the naming convention
`<pkg>_<version>_<arch>.deb` is used.

---

*(This README is included for convenience; you may remove or extend it.)*