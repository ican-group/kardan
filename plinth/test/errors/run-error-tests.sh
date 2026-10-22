#!/usr/bin/env bash
# Golden tests for Plinth compile-time error messages.
#
# Note [Error message golden tests]
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Each cases/<Name>.hs uses one Haskell construct that Plinth does not
# support. This script compiles each case with plinthc, expects the
# compilation to fail, and compares the normalized compiler output with
# golden/<GHC major.minor>/<Name>.stderr (e.g. golden/9.12/): the Core in the
# Context frames and some module names (GHC.Internal.* since GHC 9.10)
# depend on the GHC version.
#
# The plutus-tx-plugin golden tests only cover the defer-errors path,
# which drops the source location and the source snippet. These tests
# capture the real user-facing output (the "Plinth Compilation Error:"
# message printed by plinthc), so changes to error reporting and to
# source-location tracking show up as golden diffs here.
#
# Files named *Helper.hs are companion modules, not test cases.
#
# Usage:
#   GHC=/path/to/plinthc ./run-error-tests.sh          # run tests
#   GHC=/path/to/plinthc ACCEPT=1 ./run-error-tests.sh # update goldens
#
# The package databases come from the plinth/test build tree, so run
# plinthc-test.sh (or at least its build step) first.

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TEST_ROOT=$(cd "$HERE/.." && pwd)

: ${GHC:=$TEST_ROOT/../../ghc/_build/stage1/bin/plinthc}
: ${ACCEPT:=0}

if [ ! -x "$GHC" ]; then
  echo "error: plinthc not found ($GHC). Run plinthc-build.sh first," >&2
  echo "or set GHC to an installed plinthc." >&2
  exit 2
fi

VERSION=$("$GHC" --numeric-version)
GHC_SERIES=$(echo "$VERSION" | cut -d. -f1-2)
GOLDEN_DIR="$HERE/golden/$GHC_SERIES"
# cabal names the store directory after the compiler's "Project Unit Id":
# ghc-<ver>-plinthc with GHC 9.6, ghc-<ver>-inplace-plinthc with GHC 9.12.
UNIT_ID=$("$GHC" --info | sed -n 's/.*("Project Unit Id","\([^"]*\)").*/\1/p')
STORE_DB="$TEST_ROOT/_build/store/$UNIT_ID/package.db"
INPLACE_DB="$TEST_ROOT/_build/build/packagedb/ghc-$VERSION"

for db in "$STORE_DB" "$INPLACE_DB"; do
  if [ ! -d "$db" ]; then
    echo "error: package database not found: $db" >&2
    echo "Build the plinth/test project first (plinthc-test.sh)." >&2
    exit 2
  fi
done

# The unit id of the plutus-tx library itself. Since GHC 9.10, its public
# sublibrary plutus-tx-testlib is also listed under the package name
# plutus-tx, so "-package plutus-tx" can pick the sublibrary instead.
PLUTUS_TX_ID=$(cd "$INPLACE_DB" && ls plutus-tx-[0-9]*-inplace.conf | sed 's/\.conf$//')

OUTDIR=$(mktemp -d)
trap 'rm -rf "$OUTDIR"' EXIT

# The flag set of a regular Plinth project (see plinth-test.cabal,
# common plinth-options), plus preserve-source-locations: these tests
# exist to pin down how much source-location information the errors
# carry, so the location machinery must be on.
GHC_ARGS=(
  -package-db "$STORE_DB"
  -package-db "$INPLACE_DB"
  -hide-all-packages
  -package base
  -package-id "$PLUTUS_TX_ID"
  -package text
  -package bytestring
  -fplugin-opt "Plinth.Plugin:target-version=1.1.0"
  -fplugin-opt "Plinth.Plugin:preserve-source-locations"
  -fno-full-laziness -fno-spec-constr
  -fno-specialise -fno-strictness -fno-unbox-small-strict-fields
  -fno-unbox-strict-fields
  -fforce-recomp
  -fhide-source-paths
  -fdiagnostics-color=never
)

# Normalize compiler output so the goldens are stable:
#  - strip ANSI escape sequences (the source snippet uses colors);
#  - strip GHC uniques from Core dumps in Context frames
#    (e.g. "x_a5GN" -> "x", "wild_X0" -> "wild");
#  - drop GHC --make progress lines ("[1 of 2] Compiling ...");
#  - drop CRs (Windows).
# POSIX sed only: BSD sed (macOS) has no \b, \x1b or \r escapes. The
# unique pattern needs no trailing \b: the greedy [0-9a-zA-Z]* always
# ends at a non-alphanumeric character.
ESC=$(printf '\033')
CR=$(printf '\r')
normalize () {
  sed -e "s/${ESC}\\[[0-9;]*m//g" \
      -e 's/_[a-zA-Z][0-9][0-9a-zA-Z]*//g' \
      -e '/^\[ *[0-9][0-9]* of [0-9][0-9]*\]/d' \
      -e "s/${CR}\$//"
}

failures=0
total=0

cd "$HERE/cases"
for case_file in *.hs; do
  case "$case_file" in
    *Helper.hs) continue ;;
  esac
  name=${case_file%.hs}
  golden="$GOLDEN_DIR/$name.stderr"
  total=$((total + 1))

  actual_raw=$("$GHC" --make "${GHC_ARGS[@]}" -outputdir "$OUTDIR/$name" \
                 "$case_file" 2>&1)
  rc=$?

  if [ $rc -eq 0 ]; then
    echo "FAIL $name: expected the compilation to fail, but it succeeded"
    failures=$((failures + 1))
    continue
  fi

  actual=$(printf '%s\n' "$actual_raw" | normalize)

  if [ "$ACCEPT" -eq 1 ]; then
    mkdir -p "$GOLDEN_DIR"
    printf '%s\n' "$actual" > "$golden"
    echo "ACCEPT $name"
    continue
  fi

  if [ ! -f "$golden" ]; then
    echo "FAIL $name: golden file missing ($golden); run with ACCEPT=1"
    failures=$((failures + 1))
    continue
  fi

  if ! diff_out=$(printf '%s\n' "$actual" | diff -u "$golden" - 2>&1); then
    echo "FAIL $name: output differs from golden"
    echo "$diff_out" | sed 's/^/    /'
    failures=$((failures + 1))
  else
    echo "ok   $name"
  fi
done

echo ""
if [ "$ACCEPT" -eq 1 ]; then
  echo "error-tests: accepted goldens for $total cases"
elif [ $failures -eq 0 ]; then
  echo "error-tests: all $total cases passed"
else
  echo "error-tests: $failures of $total cases failed"
  exit 1
fi
