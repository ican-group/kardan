#!/usr/bin/env bash
# Bind-mount a directory of the large /mnt disk at DIR (relative to the
# workspace), so that a build there has room.
#
# The runner's workspace disk (/) has ~21 GB free; the ephemeral disk at /mnt
# has ~70 GB. We bind-mount (rather than symlink) so DIR stays a real
# directory: a symlinked build root can confuse path tracking in
# Hadrian/Cabal.
#
# Usage: bind-mount.sh DIR   (e.g. _build, or ghc/_build after the submodules
#                             are fetched: a non-empty ghc/ stops the clone)
set -euo pipefail

dir="$1"
src="/mnt/$(echo "$dir" | tr / _)"
sudo mkdir -p "$src"
mkdir -p "$GITHUB_WORKSPACE/$dir"
sudo mount --bind "$src" "$GITHUB_WORKSPACE/$dir"
sudo chown "$USER" "$GITHUB_WORKSPACE/$dir"
