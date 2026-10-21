#!/usr/bin/env bash
set -euo pipefail
LOCAL_HAPPY="$PWD/_build/tools/happy"
LOCAL_ALEX="$PWD/_build/tools/alex"

UNAME_S=$(uname -s)
case "$UNAME_S" in
    MINGW*|MSYS*) IS_WINDOWS=1; EXE_EXT=".exe" ;;
    *)            IS_WINDOWS=0; EXE_EXT="" ;;
esac

RELEASE_HADRIAN_ARGS=""
DEV_HADRIAN_ARGS="--docs=none"
# expose_unfoldings: base, ghc-prim and ghc-bignum must have the
# unfoldings of all their definitions, because the Plinth compiler
# translates them. Kardan does not compile these libraries, so they do
# not get the INLINABLE pragmas that the Plinth plugin adds.
RELEASE_FLAVOUR="release+expose_unfoldings"
# Note [Lean CI flavour]
# ~~~~~~~~~~~~~~~~~~~~~~~
# The dev/CI flavour is just "release" (+expose_unfoldings, see above):
#  - debug_info/debug_ghc compile GHC and its libraries with DWARF (-g3), which
#    inflates the build tree 2-3x and is the main disk-space hog on CI runners;
#  - +assertions builds GHC with -DDEBUG, which slows compilation of GHC itself
#    *and* of every package built with the resulting compiler (i.e. the Plinth
#    test project). Dropping it keeps CI within its time budget.
# Use RELEASE=1 for a clean release build (adds docs etc.).
DEV_FLAVOUR="release+expose_unfoldings"

# platform-specific default configure arguments
case "$UNAME_S" in
    MINGW*|MSYS*) DEFAULT_CONFIGURE_ARGS="--enable-tarballs-autodownload" ;;
    Darwin*)      DEFAULT_CONFIGURE_ARGS="--with-intree-gmp" ;;
    *)            DEFAULT_CONFIGURE_ARGS="" ;;
esac

RELEASE_CONFIGURE_ARGS="$DEFAULT_CONFIGURE_ARGS"
DEV_CONFIGURE_ARGS="$DEFAULT_CONFIGURE_ARGS"

####################################################################
# edit configuration here:

: ${REBUILD:=0} # set to 1 to force rebuild
: ${RELEASE:=0} # set to 1 to build release version including documentation (more build dependencies)
: ${BINDIST:=0} # set to 1 to produce the fixed-up kardan bindist + archive while keeping the dev (assertions) flavour
: ${RELEASE_VERSION:=} # set to e.g. 9.6.169.1 to stamp the compiler with exactly that version. See Note [Release versioning]

# program locations
: ${GHC:=$(command -v ghc-9.6.7 2>/dev/null || true)}
: ${CABAL:=$(command -v cabal 2>/dev/null || true)}
: ${PYTHON:=$(command -v python3 2>/dev/null || true)}
: ${HAPPY:=$( [ -x "$LOCAL_HAPPY" ] && echo "$LOCAL_HAPPY" || command -v happy-1.20.1.1 2>/dev/null || true)}
: ${ALEX:=$( [ -x "$LOCAL_ALEX" ] && echo "$LOCAL_ALEX" || command -v alex 2>/dev/null || true)}
: ${TAR:=$(command -v tar 2>/dev/null || true)}
: ${XZ:=$(command -v xz 2>/dev/null || true)}

# override default arguments
: ${HADRIAN_ARGS:=$( [ "$RELEASE" -eq 1 ] && echo "$RELEASE_HADRIAN_ARGS" || echo "$DEV_HADRIAN_ARGS" )}
: ${CONFIGURE_ARGS:=$( [ "$RELEASE" -eq 1 ] && echo "$RELEASE_CONFIGURE_ARGS" || echo "$DEV_CONFIGURE_ARGS" )}
: ${FLAVOUR:=$( [ "$RELEASE" -eq 1 ] && echo "$RELEASE_FLAVOUR" || echo "$DEV_FLAVOUR" )}

# end configuration
####################################################################

# version comparison: returns 0 if $1 >= $2
version_ge() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

if [ ! -x "$GHC" ]; then
  echo "GHC not found: $GHC"
  exit 1
fi
if [ -z "$CABAL" ] || [ ! -x "$CABAL" ]; then
  echo "cabal not found"
  exit 1
fi
CABAL_VERSION=$("$CABAL" --numeric-version)
if ! version_ge "$CABAL_VERSION" "3.14.2.0"; then
  echo "cabal version $CABAL_VERSION is too old, need at least 3.14.2.0"
  exit 1
fi
if [ -z "$HAPPY" ] || [ ! -x "$HAPPY" ]; then
  echo "Happy not found, building happy-1.20.1.1 locally..."
  "$CABAL" install happy-1.20.1.1 -w "$GHC" --install-method=copy --overwrite-policy=always --installdir="$PWD/_build/tools"
  HAPPY="$LOCAL_HAPPY"
  if [ ! -x "$HAPPY" ]; then
    echo "Failed to build happy"
    exit 1
  fi
fi
if [ -z "$ALEX" ] || [ ! -x "$ALEX" ]; then
  echo "Alex not found, building alex-3.5.4.0 locally..."
  "$CABAL" install alex-3.5.4.0 -w "$GHC" --install-method=copy --overwrite-policy=always --installdir="$PWD/_build/tools"
  ALEX="$LOCAL_ALEX"
  if [ ! -x "$ALEX" ]; then
    echo "Failed to build alex"
    exit 1
  fi
fi

if [ -z "$TAR" ] || [ ! -x "$TAR" ]; then
  echo "tar not found"
  exit 1
fi
if [ -z "$XZ" ] || [ ! -x "$XZ" ]; then
  echo "xz not found"
  exit 1
fi
if [ -z "$PYTHON" ] || [ ! -x "$PYTHON" ]; then
  echo "python3 not found"
  exit 1
fi

export GHC
export CABAL
export HAPPY
export ALEX
export PYTHON

echo "using tools: "
echo " GHC:    $GHC"
echo " cabal:  $CABAL ($CABAL_VERSION)"
echo " happy:  $HAPPY"
echo " alex:   $ALEX"
echo " python: $PYTHON"
echo " tar:    $TAR"
echo " xz:     $XZ"

####################################################################
# do the things

BASE=$PWD

# check the submodules
if [ ! -d plutus/plutus-tx ] || [ ! -f ghc/configure.ac ]; then
  echo "ghc or plutus submodule not found, please fetch submodules (git submodule update --init --recursive)"
  exit 1
fi

# Note [Release versioning]
# ~~~~~~~~~~~~~~~~~~~~~~~~~
# Two unrelated things are spelled RELEASE:
#  - this script's RELEASE=1 picks the release flavour (docs, more build deps);
#  - configure's RELEASE=YES/NO decides whether the version in ghc/configure.ac gets
#    a fourth component appended (the date of the last commit, i.e. a snapshot
#    version) or is used verbatim.
# They must not be confused, so the value handed to configure is always passed
# explicitly below and never inherited from the environment.
#
# ghc/configure.ac (the kardan branch of the GHC fork) carries the
# three-component base (9.6.<plinth>) and a plain build
# is stamped 9.6.169.<date>. A release build sets RELEASE_VERSION=9.6.169.1: the
# base is rewritten to that full version and RELEASE=YES keeps configure from
# appending anything, so the compiler reports exactly the released version.
#
# The release counter lives in the release tag (CI passes RELEASE_VERSION=${TAG#v})
# rather than in ghc/configure.ac, because a committed four-component base would make
# every later snapshot build five components (9.6.169.1.20260803) -- one more
# than the tools accept.
CONFIGURE_RELEASE=NO
if [ -n "$RELEASE_VERSION" ]; then
  BASE_VERSION=$(sed -n 's/^AC_INIT(\[[^]]*\], *\[\([^]]*\)\].*/\1/p' ghc/configure.ac)
  case "$RELEASE_VERSION" in
    # already rewritten by an earlier run of this script: nothing to do
    "$BASE_VERSION") ;;
    "$BASE_VERSION".*)
      echo "stamping release version $RELEASE_VERSION (was $BASE_VERSION)"
      sed "s/^\(AC_INIT(\[[^]]*\], *\[\)$BASE_VERSION\(\]\)/\1$RELEASE_VERSION\2/" \
        ghc/configure.ac > ghc/configure.ac.tmp
      mv ghc/configure.ac.tmp ghc/configure.ac
      # ghc/configure.ac changed, so ./configure has to be regenerated and re-run
      rm -f ghc/configure ghc/mk/config.h
      ;;
    *)
      echo "error: RELEASE_VERSION=$RELEASE_VERSION does not extend the version in ghc/configure.ac ($BASE_VERSION)"
      exit 1
      ;;
  esac
  CONFIGURE_RELEASE=YES
fi

# build boot GHC
DID_BOOT_OR_CONFIGURE=0
if [ ! -x ghc/configure ] || [ "$REBUILD" -eq 1 ]; then
  echo "booting..."
  (cd ghc && ./boot)
  DID_BOOT_OR_CONFIGURE=1
fi
if [ ! -e ghc/mk/config.h ] || [ "$REBUILD" -eq 1 ]; then
  echo "configuring..."
  (
  # On Windows/MinGW64, ensure we use the CA bundle from MSYS2 to avoid SSL errors when downloading tarballs
  if [ "$IS_WINDOWS" -eq 1 ]; then
      export SSL_CERT_FILE="$(cygpath -w /mingw64/etc/ssl/certs/ca-bundle.crt)"
  fi
  # RELEASE is configure's own knob, not this script's. See Note [Release versioning].
  cd ghc
  RELEASE="$CONFIGURE_RELEASE" ./configure $CONFIGURE_ARGS
  )
  DID_BOOT_OR_CONFIGURE=1
fi

# hadrian builds in its default build root, ghc/_build: a build root outside
# the GHC tree does not work (absolute: GHC #27427; relative: the rts does not
# find its generated headers). The kardan outputs (tools, the cabal build of
# kardan) stay in _build.
GHC_BUILD="$BASE/ghc/_build"

if [ ! -x "$GHC_BUILD/stage1/bin/ghc" ] || [ "$REBUILD" -eq 1 ]; then
  echo "building..."
  echo "(cd ghc && ./hadrian/build -j --flavour=$FLAVOUR $HADRIAN_ARGS binary-dist-dir)"
  (cd ghc && ./hadrian/build -j --flavour=$FLAVOUR $HADRIAN_ARGS binary-dist-dir)
fi

# build Kardan

STAGE="stage-plinth"
BOOT_GHC="$GHC_BUILD/stage1/bin/ghc"
TARGET_PLATFORM=$("$BOOT_GHC" --print-target-platform)
VERSION=$("$BOOT_GHC" --numeric-version)

# The bindist name, and hence the version ghcup advertises, is derived from this.
# If it doesn't match the release tag, the channel would point at a version no
# tarball provides, so stop here rather than publish that.
if [ -n "$RELEASE_VERSION" ] && [ "$VERSION" != "$RELEASE_VERSION" ]; then
  echo "error: built compiler reports version $VERSION, expected $RELEASE_VERSION"
  echo "       (stale _build? re-run with REBUILD=1)"
  exit 1
fi

CABAL_PROJECT_ARGS="--project-file=cabal.project"

CABAL_ARGS="\
    --remote-repo-cache _build/packages \
    --store-dir=_build/${STAGE}/${TARGET_PLATFORM}/store \
    --logs-dir=_build/${STAGE}/logs"

CABAL_BUILD_ARGS="\
    -j -w ${BOOT_GHC} \
    --builddir=_build/${STAGE}/${TARGET_PLATFORM} \
    --ghc-options=\"-fhide-source-paths\""

# On Windows/MinGW64, ensure we use Git for Windows (not MSYS2 git) and
# prevent git from hanging on interactive credential/host-key prompts
# when called as a subprocess by cabal.
if [ "$IS_WINDOWS" -eq 1 ]; then
    if [ -d "/c/Program Files/Git/bin" ]; then
        export PATH="/c/Program Files/Git/bin:$PATH"
    fi
    export GIT_TERMINAL_PROMPT=0
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0="core.longpaths"
    export GIT_CONFIG_VALUE_0="true"
fi

(
    echo "building kardan"
    cd plinth
    echo "cabal update..."
    "$CABAL" ${CABAL_PROJECT_ARGS} ${CABAL_ARGS} update
    echo "cabal build..."
    "$CABAL" ${CABAL_PROJECT_ARGS} ${CABAL_ARGS} build ${CABAL_BUILD_ARGS} ghc-bin:exe:ghc
)

# add kardan to the _build dir and the bindists
CWRAPPER_DIR="$BASE/ghc/hadrian/bindist/cwrappers"

DEST_KARDAN="$GHC_BUILD/stage1/bin/kardan${EXE_EXT}"

(
    cd plinth
    # list-bin may first print the output of a source-repository-package
    # checkout (e.g. git's "HEAD is now at ...") on stdout: keep the last line.
    SRC_KARDAN=$("$CABAL" ${CABAL_PROJECT_ARGS} ${CABAL_ARGS} list-bin ${CABAL_BUILD_ARGS} ghc-bin:exe:ghc | tail -n 1)
    echo "installing kardan: $SRC_KARDAN => $DEST_KARDAN"

    # add to build dir (needed for testing, so always done)
    cp "$SRC_KARDAN" "$DEST_KARDAN"

    # The bindist fixup below only matters for the shippable bindist, produced
    # for RELEASE=1 (release flavour + docs) or BINDIST=1 (current flavour, e.g.
    # the lean CI flavour - see Note [Lean CI flavour]). The CI test job consumes
    # this bindist, so it builds with BINDIST=1. Otherwise skip the fixup to avoid
    # duplicating the whole bindist tree on disk.
    if [ "$RELEASE" -ne 1 ] && [ "$BINDIST" -ne 1 ]; then
        exit 0
    fi

    # fixup the bindist:
    #  - add kardan with the static Plinth plugin
    #  - remove boot GHC, since we don't want Kardan to replace the user's GHC
    for dir in "$GHC_BUILD"/bindist/*; do
        if [ -d "$dir" ]; then
            echo "adding kardan to bindist: $dir"
            if [ "$IS_WINDOWS" -eq 1 ]; then
                # Windows: copy versioned .exe and compile a C wrapper
                cp "$SRC_KARDAN" "$dir/bin/kardan-$VERSION.exe"
                "$BOOT_GHC" -no-hs-main \
                    -o "$dir/bin/kardan.exe" \
                    "-I$CWRAPPER_DIR" \
                    "-DEXE_PATH=\"kardan-$VERSION.exe\"" \
                    "-DINTERACTIVE_PROCESS=0" \
                    "$CWRAPPER_DIR/version-wrapper.c" \
                    "$CWRAPPER_DIR/getLocation.c" \
                    "$CWRAPPER_DIR/cwrapper.c"
            else
                # Unix: copy versioned binary and symlink
                cp "$SRC_KARDAN" "$dir/bin/kardan-$VERSION"
                ( cd "$dir/bin" && ln -sf "kardan-$VERSION" "kardan" )
            fi

            # Add wrapper scripts so `make install` creates $PREFIX/bin/kardan
            mkdir -p "$dir/wrappers"
            echo 'exec "$executablename" -B"$libdir" ${1+"$@"}' > "$dir/wrappers/kardan-$VERSION"
            ( cd "$dir/wrappers" && ln -sf "kardan-$VERSION" "kardan" )

            # remove the boot GHC from the bindist
            rm -f "$dir"/bin/ghc
            rm -f "$dir"/bin/ghc.exe
            rm -f "$dir"/bin/ghc-$VERSION
            rm -f "$dir"/bin/ghc-$VERSION.exe
            # rename runhaskell/runghc
            mv -f "$dir"/bin/runhaskell "$dir"/bin/kardan-runhaskell 2>/dev/null || true
            mv -f "$dir"/bin/runghc "$dir"/bin/kardan-runghc 2>/dev/null || true
            # XXX wrappers on Windows, other tools like unlit need to be renamed?
        fi
    done
)

# Note [Detecting musl]
# ~~~~~~~~~~~~~~~~~~~~~
# Don't detect musl with `ldd --version | grep musl`: musl's ldd has no
# --version, so it prints its banner (which does contain "musl") and exits 1.
# Under `set -o pipefail` the pipeline then reports failure even though grep
# matched, so musl was silently detected as glibc. glibc's ldd exits 0, which is
# why only the musl side was broken.
#
# A missing -musl suffix is not cosmetic: generate-ghcup-metadata.py derives the
# ghcup platform from the bindist name, so the musl bindist was published as
# Linux_UnknownLinux. ghcup deliberately does not fall back from Alpine to
# UnknownLinux (a glibc bindist cannot run on musl), so `ghcup install kardan`
# failed on Alpine with "Unable to find a download". The two bindists would also
# collide under the same file name in the GitHub Release.
#
# The suffix has to rename the bindist *directory* too, not just the archive:
# hadrian names the directory after the target platform only, so suffixing only
# the archive name left `tar` with no such directory to pack ("Cannot stat"), and
# the top-level directory inside the tarball is exactly what ghcup is told to
# descend into (dlSubdir).

# create bindist archive after fixup. The tar|xz is slow and needs extra disk,
# so only do it for a shippable bindist: RELEASE=1, or BINDIST=1 to hand the
# bindist to the CI test job. -T0 lets xz use all cores to keep CI time down.
if [ "$RELEASE" -eq 1 ] || [ "$BINDIST" -eq 1 ]; then
    echo "creating bindist archive..."
    # Append a -musl suffix to the bindist name on musl libc so glibc and musl
    # bindists for the same platform don't collide. See Note [Detecting musl].
    LIBC_SUFFIX=""
    case "$UNAME_S" in
        Linux*)
            ldd_out=$(ldd --version 2>&1 || true)
            case "$ldd_out" in *musl*) LIBC_SUFFIX="-musl" ;; esac
            ;;
    esac
    # hadrian's binary-dist-dir names the directory ghc-<ver>-<platform>, so
    # rename it to kardan-<ver>-<platform>[-musl] rather than just naming the
    # archive: the tarball's top-level directory has to match the archive name,
    # since that is what generate-ghcup-metadata.py records as ghcup's dlSubdir.
    # Guarded on the source existing so re-running over an already-renamed
    # bindist keeps it instead of deleting it.
    HADRIAN_BINDIST="ghc-$VERSION-$TARGET_PLATFORM"
    BINDIST_NAME="kardan-$VERSION-$TARGET_PLATFORM${LIBC_SUFFIX}"
    if [ -d "$GHC_BUILD/bindist/$HADRIAN_BINDIST" ]; then
        rm -rf "$GHC_BUILD/bindist/$BINDIST_NAME"
        mv "$GHC_BUILD/bindist/$HADRIAN_BINDIST" "$GHC_BUILD/bindist/$BINDIST_NAME"
    fi
    (cd "$GHC_BUILD/bindist" && "$TAR" -cf - "$BINDIST_NAME" | "$XZ" -T0 > "$BINDIST_NAME.tar.xz")
fi

