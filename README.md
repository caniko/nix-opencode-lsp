# nix-opencode-lsp

Composable OpenCode LSP configuration for direnv-managed Nix projects.

OpenCode merges configuration from multiple sources, but a shell can only set
one `OPENCODE_CONFIG` path. These shells instead merge their generated LSP
configuration into `OPENCODE_CONFIG_CONTENT`, so multiple direnv-loaded shells
can cooperate.

## Usage

Base Nix/Rust/TOML profile:

```sh
use flake git+ssh://git@codeberg.org/caniko/nix-opencode-lsp.git#opencode-lsp
```

Python profile:

```sh
use flake git+ssh://git@codeberg.org/caniko/nix-opencode-lsp.git#opencode-lsp-python
```

Harbor flakes re-export compatible profiles. Prefer those in Rust/Python harbor
projects so language-server versions track the harbor stack.
