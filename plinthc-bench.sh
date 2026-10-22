#!/usr/bin/env bash
# Run plutus-benchmark test-suites with our plinthc and report diffs
# against the golden files committed under plutus/plutus-benchmark/*/test/9.6.
#
# Each test-suite is a tasty runner. When a golden comparison fails,
# tasty prints a unified diff to the test-suite's stdout, which cabal
# forwards to our log when --test-show-details=direct is used.
#
# Cabal runs each test binary with cwd = the package directory
# (plutus-benchmark), so the goldens at coop/test/9.6/, nofib/test/9.6/,
# etc. resolve without copying files around.

set -euo pipefail

BASE=$PWD
PLINTHC="$BASE/ghc/_build/stage1/bin/plinthc"
PROJECT_DIR="$BASE/plinth/coop-test"
BENCH_DIR="$BASE/plutus/plutus-benchmark"
TARGET_PKG="plutus-benchmark"

: ${CABAL:=$(command -v cabal 2>/dev/null || true)}

if [ ! -x "$PLINTHC" ]; then
  echo "plinthc not found at $PLINTHC"
  echo "run ./plinthc-build.sh first"
  exit 1
fi
if [ -z "$CABAL" ] || [ ! -x "$CABAL" ]; then
  echo "cabal not found"
  exit 1
fi
if [ ! -d "$BENCH_DIR" ]; then
  echo "missing $BENCH_DIR"
  echo "fetch the plutus submodule"
  exit 1
fi

CABAL_ARGS=(
  --remote-repo-cache="$BASE/_build/packages"
  --store-dir="$BASE/_build/stage-plinth-coop/store"
  --logs-dir="$BASE/_build/stage-plinth-coop/logs"
  --enable-tests
)

cd "$PROJECT_DIR"

echo "cabal update..."
"$CABAL" "${CABAL_ARGS[@]}" update

echo "building $TARGET_PKG:tests with plinthc..."
"$CABAL" "${CABAL_ARGS[@]}" build -j \
  -w "$PLINTHC" \
  --ghc-options=-fhide-source-paths \
  "$TARGET_PKG:tests"

echo ""
echo "running $TARGET_PKG test-suites..."
echo ""

# Use --test-show-details=direct so tasty's golden diffs are streamed
# to stdout as each test runs, instead of being hidden in per-test logs.
# -j1 keeps output readable.
set +e
"$CABAL" "${CABAL_ARGS[@]}" test -j1 \
  -w "$PLINTHC" \
  --keep-going \
  --test-show-details=direct \
  "$TARGET_PKG"
RC=$?
set -e

echo ""
if [ $RC -eq 0 ]; then
  echo "plinthc-bench: all $TARGET_PKG tests matched golden (exit $RC)"
else
  echo "plinthc-bench: some $TARGET_PKG tests differ from golden (exit $RC)"
  echo "see diffs above, or inspect .actual sidecar files under:"
  echo "  $BENCH_DIR/*/test/"
  actuals=$(find "$BENCH_DIR" -name '*.actual' 2>/dev/null)
  if [ -n "$actuals" ]; then
    echo ""
    echo "actual files written:"
    echo "$actuals"
  fi
fi

exit $RC
