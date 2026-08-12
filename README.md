# nix-opencode-lsp

Composable OpenCode LSP configuration for direnv-managed Nix projects.

OpenCode merges configuration from multiple sources, but a shell can only set
one `OPENCODE_CONFIG` path. These shells instead merge their generated LSP
configuration into `OPENCODE_CONFIG_CONTENT`, so multiple direnv-loaded shells
can cooperate.

## Usage

Base Nix/Rust/TOML profile:

```sh
use flake git+ssh://git@github.com/caniko/nix-opencode-lsp.git#opencode-lsp
```

Python profile:

```sh
use flake git+ssh://git@github.com/caniko/nix-opencode-lsp.git#opencode-lsp-python
```

PKL profile:

```nix
let
  pklLsp = opencodeLsp.lib.mkPklLspReleasePackage {
    inherit pkgs;
  };
in
  opencodeLsp.lib.mkShell {
    inherit pkgs pklLsp;
    profiles = ["pkl"];
  }
```

The PKL package defaults to `caniko/pkl-lsp` `0.1.0` Codeberg release assets.
Pass `version` and `hashes` to `mkPklLspReleasePackage` when upgrading.

Harbor flakes re-export compatible profiles. Prefer those in Rust/Python harbor
projects so language-server versions track the harbor stack.
