#!/usr/bin/env bash
set -euo pipefail

# Clean all build directories created by kardan-build.sh
#
# Usage:
#   ./kardan-clean.sh          # clean everything
#   ./kardan-clean.sh plinth   # clean only the plinth (cabal) build
#   ./kardan-clean.sh ghc      # clean only the GHC (hadrian) build
#   ./kardan-clean.sh tools    # clean only locally built tools (happy, alex)

what="${1:-all}"

case "$what" in
    plinth)
        echo "Cleaning plinth build..."
        rm -rf _build/stage-plinth
        (cd plinth && rm -rf dist-newstyle)
        ;;
    ghc)
        echo "Cleaning GHC build..."
        rm -rf ghc/_build
        # clean configure artifacts
        rm -f ghc/mk/config.h ghc/mk/config.mk ghc/config.log ghc/config.status
        ;;
    tools)
        echo "Cleaning locally built tools..."
        rm -rf _build/tools
        ;;
    all)
        echo "Cleaning all build directories..."
        rm -rf _build ghc/_build
        (cd plinth && rm -rf dist-newstyle)
        # clean configure artifacts
        rm -f ghc/mk/config.h ghc/mk/config.mk ghc/config.log ghc/config.status
        ;;
    *)
        echo "Usage: $0 [all|ghc|plinth|tools]"
        exit 1
        ;;
esac

echo "Done."
