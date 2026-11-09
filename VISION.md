# nix-opencode-lsp vision

A small Nix flake that gives direnv-managed projects composable OpenCode
language-server configuration. OpenCode merges configuration from several
sources, but a shell can only set one `OPENCODE_CONFIG` path; these shells merge
a generated LSP profile into `OPENCODE_CONFIG_CONTENT` instead, so several
direnv-loaded shells can cooperate in one session.

## Problem

Every project wants different language servers, yet OpenCode reads one config
slot. A per-project full config either overwrites the user's settings or loses
to a sibling shell, and LSP versions drift per repository instead of tracking
the toolchain the rest of the stack uses.

## Principles

- **Merge, don't replace.** `mkLspShell` merges with `jq`, preserving unrelated
  top-level keys and combining `.lsp` maps; a check asserts that a pre-existing
  custom LSP entry survives the merge.
- **Fail loudly inside direnv.** A failed merge exits the direnv evaluation
  rather than exporting a corrupted config.
- **Profiles, not bespoke configs.** The base profile ships `nixd`, `rust`, and
  `taplo`; `python` adds `basedpyright` and `ruff` and disables `pyright`; `pkl`
  adds a pinned `pkl-lsp` release.
- **Pinned release assets.** `mkPklLspReleasePackage` takes an explicit version
  and per-platform hashes, and throws for systems without release assets.
- **The `lsp` key is the whole surface.** Models, providers, permissions, and
  sessions are not part of what a shell writes.

## Scope

Library entry points `mkShell`, `mkConfig`, `mkConfigPackage`, `mkLspShell`,
`mkLspConfigPackage`, `mkPklLspReleasePackage`, and `mkServers`; flake outputs
are `lib`, per-profile config packages and devShells, and checks that assert the
JSON shape of each profile plus merge-preservation behaviour.

## Non-goals

- Not a general OpenCode configuration manager; it only contributes `lsp`.
- Not a language-server registry: the base profile takes `rust-analyzer` from
  nixpkgs, and Pkl support comes from a pinned external release.

## Direction

Recent fixes keep the merge path honest: one commit stops JSON corruption when
merging, another makes a failed merge abort the direnv evaluation. Input pins
have moved to GitHub. No further roadmap is documented.

## Place in the fleet

`canix/flake.nix` pins the flake as an input and its comment records that
`lib.mkPklLspReleasePackage`/`mkShell` are exposed to canix shells, while
transitive copies owned by `harbor-rs`/`harbor-py` keep their own pins.
