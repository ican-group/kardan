---
title: Build plinthc from source
permalink: /how-to/build/
---
This guide explains how to build
[plinthc]({% link explanation/standalone-compiler.md %}) (`plinthc`)
from source. Most users do not need this: the recommended way to get
`plinthc` is to
[install a released binary via ghcup]({% link how-to/install.md %}). Build
from source when you work on the compiler itself, or when no binary
distribution covers your platform.

## Prerequisites

`plinthc-build.sh` expects the following tools on `PATH`:

| Tool      | Requirement                                          |
| --------- | ---------------------------------------------------- |
| `ghc`     | boot compiler `ghc-9.6.7`                            |
| `cabal`   | `>= 3.14.2.0`                                         |
| `happy`   | `happy-1.20.1.1` (built locally if missing)          |
| `alex`    | `alex-3.5.4.0` (built locally if missing)            |
| `python3` | required by Hadrian                                  |
| `tar`     | required to produce the binary distribution archive  |
| `xz`      | required to compress the binary distribution archive |

`happy` and `alex` are built locally into `_build/tools/` if they are not
found, so they are effectively optional. The others must be present.

## 1. Clone with submodules

The compiler sources come from two submodules, so clone recursively:

| Submodule | Repository                     | Branch          | Provides                                               |
| --------- | ------------------------------ | --------------- | ------------------------------------------------------ |
| `ghc`     | `ican-group/ghc-plinth`        | `plinthc-9.6.7` | GHC 9.6.7 with the plinthc patches                     |
| `plutus`  | `ican-group/ghc-plinth-plutus` | `plinthc-1.69`  | `plutus-tx`, `plutus-tx-plugin` and `plutus-core` 1.69 |


```console
$ git clone --recurse-submodules git@github.com:ican-group/plinthc.git
```

If you already cloned without `--recurse-submodules`, fetch them with:

```console
$ git submodule update --init --recursive
```

## 2. Run the build script

From the root of the repository:

```console
$ ./plinthc-build.sh
```

The script bootstraps GHC in `ghc/` and then builds `plinthc`. What it produces is
described under [Build outputs](#build-outputs) below.

## Build options

`plinthc-build.sh` is controlled by environment variables. The two most common
force a full rebuild or select the release flavour:

```console
$ REBUILD=1 ./plinthc-build.sh   # re-boot, re-configure, and rebuild from scratch
$ RELEASE=1 ./plinthc-build.sh   # release flavour, which also builds documentation
```

| Variable  | Default | Effect                                                        |
| --------- | ------- | ------------------------------------------------------------- |
| `REBUILD` | `0`     | Set to `1` to force a full rebuild (re-boot, re-configure).   |
| `RELEASE` | `0`     | Set to `1` to build the release flavour including documentation (more build dependencies). |

It also honours tool-location overrides such as `GHC`, `CABAL`, `HAPPY`,
`ALEX`, and `PYTHON`, as well as `HADRIAN_ARGS`, `CONFIGURE_ARGS`, and
`FLAVOUR`, when you need to point it at specific tools or change the build
flavour.

## Build outputs

When `plinthc-build.sh` finishes it has produced two things.

**The compiler.** The development build is installed at:

```
ghc/_build/stage1/bin/plinthc
```

This is the binary you point cabal at (see
[Use plinthc in a project]({% link how-to/use.md %})).

**Binary distribution archive.** With `RELEASE=1` or `BINDIST=1`, a
relocatable bindist is produced under `ghc/_build/bindist/`:

```
ghc/_build/bindist/plinthc-<version>-<platform>.tar.xz
```

The build script fixes up the bindist so that it ships `plinthc` (with the
built-in Plinth plugin) instead of the boot GHC:

- `plinthc` is added (as `plinthc-<version>` plus a `plinthc` wrapper).
- The boot `ghc` binary is removed, so installing the bindist does not replace
  a user's existing GHC.
- `runghc` and `runhaskell` are renamed to `plinthc-runghc` and `plinthc-runhaskell`.

Installing the bindist therefore creates `$PREFIX/bin/plinthc`.

## Test and benchmark

With `plinthc` built, two scripts exercise it. Both run from the root of the
repository.

### Run the example project tests

```console
$ ./plinthc-test.sh
```

It builds the example Plinth project under `plinth/test/` with `plinthc` and
regenerates its expected outputs. Set `CLEAN=1` to force a clean rebuild:

```console
$ CLEAN=1 ./plinthc-test.sh
```

### Run the benchmarks

`plinthc-bench.sh` builds and runs the `plutus-benchmark` test-suites with
`plinthc` and reports any diffs against the golden files committed under
`plutus/plutus-benchmark/` (it requires the `plutus` submodule):

```console
$ ./plinthc-bench.sh
```

Each test-suite is a [tasty](https://hackage.haskell.org/package/tasty) runner.
When a golden comparison fails, the unified diff is streamed to stdout and an
`.actual` sidecar file is written next to the corresponding golden file under
`plutus/plutus-benchmark/*/test/`.
