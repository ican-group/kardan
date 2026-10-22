plinthc
=======

plinthc is a [GHC][ghc]-based compiler that embeds the [Plinth][plinth]
compiler, used to write smart contracts for the [Cardano][cardano]
blockchain. Plinth (formerly known as Plutus Tx) is a subset of Haskell
compiled to Plutus Core via a GHC Core plugin, built into plinthc as a static
plugin. The build produces `plinthc`, a compiler that installs alongside your
normal GHC and never replaces it.

Documentation
=============

The documentation lives on the documentation site:

  **<https://ican-group.github.io/plinthc/>**

It covers the installation of `plinthc` (via ghcup), its use in a project,
the build from source, the tests, and background on how the compiler works.

Repository layout
=================

This repository holds the build scripts, the tests, CI and the examples. The
compiler sources are in two submodules. Each one is an upstream release plus
a small set of patches:

| Path      | Repository                     | Branch           | Upstream base            |
|-----------|--------------------------------|------------------|--------------------------|
| `ghc/`    | `ican-group/ghc-plinth`        | `plinthc-9.12.4` | GHC `ghc-9.12.4-release` |
| `plutus/` | `ican-group/ghc-plinth-plutus` | `plinthc-1.70`   | plutus `1.70.0.0`        |

This is the `ghc-9.12` branch: plinthc on GHC 9.12. The `master` branch is
the same product on GHC 9.6 (`ghc` submodule on `plinthc-9.6.7`). Both share
the plutus fork branch and publish to the same ghcup channel: 9.12-based
releases are 9.12.<plinth>.N, 9.6-based ones 9.6.<plinth>.N.

Get the sources with `git clone --recursive`, or run
`git submodule update --init --recursive` after the clone. Then:

    ./plinthc-build.sh    # build GHC (hadrian, in ghc/_build/) and plinthc
    ./plinthc-test.sh     # run the tests with ghc/_build/stage1/bin/plinthc

To update to a new Plinth (plutus) release:

1. In the plutus fork, put the plinthc patches on the new release as a new
   `plinthc-1.NN` branch.
2. In the GHC fork, set the third version component in `configure.ac` to the
   new Plinth version (e.g. 1.71 -> `9.6.171`). See the note in that file.
3. Here, bump both gitlinks and the `plutus-*` bounds in
   `plinth/test/plinth-test.cabal`. Then mirror upstream's solver settings in
   `plinth/cabal.project` and `plinth/test/cabal.project`.

To update to a new GHC release, rebase the GHC fork branch onto the new
release tag (e.g. `plinthc-9.6.8` on `ghc-9.6.8-release`), then bump the `ghc`
gitlink.

Making a release
================

Releases are cut from **Actions -> CI -> Run workflow**, with
`release_version` set and `publish` ticked. See Note [ghcup release channel]
in `.github/workflows/ci.yml` for the details.

  [ghc]: https://www.haskell.org/ghc/ "www.haskell.org/ghc/"
  [plinth]: https://plutus.cardano.intersectmbo.org/docs/
          "Plinth and Plutus Core Documentation"
  [cardano]: https://cardano.org/ "cardano.org"
