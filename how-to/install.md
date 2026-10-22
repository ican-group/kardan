---
title: Install plinthc
permalink: /how-to/install/
---
[plinthc]({% link explanation/standalone-compiler.md %}) (`plinthc`)
is distributed as a custom tool named `plinthc` for
[ghcup](https://www.haskell.org/ghcup/), the standard installer for Haskell
toolchains. Installing it via ghcup, as described here, is the recommended way
to get it. To work on the compiler itself, or when no binary distribution
covers your platform, [build it from source]({% link how-to/build.md %})
instead.

## Install via ghcup

You need ghcup 0.2.1.0 or newer (check with `ghcup --version`). Add the plinthc
release channel, then install and activate the tool:

```console
$ ghcup config add-release-channel https://raw.githubusercontent.com/ican-group/plinthc/ghcup-channel/ghcup-plinthc.yaml
$ ghcup install plinthc 9.6.169.4
$ ghcup set plinthc 9.6.169.4
```

`ghcup install` downloads the binary distribution for your platform and
installs it under ghcup's own directory; `ghcup set` then links `plinthc` and
`plinthc-pkg` (the compiler's own `ghc-pkg`) into ghcup's `bin` directory
(`~/.ghcup/bin` by default), which is already on `PATH` for ghcup users.
Verify with:

```console
$ plinthc --version
```

Installing `plinthc` does not affect any GHC installed by ghcup: only
`plinthc*` binaries are put on `PATH`, so your regular `ghc` is left untouched.

## Supported platforms

Binary distributions are published for:

- Linux, x86_64 and aarch64 (glibc, and musl/Alpine)
- macOS, Apple Silicon
- Windows, x86_64

List the available versions with `ghcup list -t plinthc`.

Once installed, head over to
[Use plinthc in a project]({% link how-to/use.md %}).
