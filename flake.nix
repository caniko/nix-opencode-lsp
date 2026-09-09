{
  description = "Composable OpenCode LSP shells for direnv-managed Nix projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    lib = import ./lib {inherit nixpkgs;};
  in
    {
      inherit lib;
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        pklLsp = lib.mkPklLspReleasePackage {inherit pkgs;};
      in {
        packages = {
          opencode-lsp-config = lib.mkConfigPackage {inherit pkgs;};
          opencode-lsp-config-python = lib.mkConfigPackage {
            inherit pkgs;
            profiles = ["python"];
          };
          opencode-lsp-config-pkl = lib.mkConfigPackage {
            inherit pkgs;
            profiles = ["pkl"];
            inherit pklLsp;
          };
          default = self.packages.${system}.opencode-lsp-config;
        };

        devShells = {
          opencode-lsp = lib.mkShell {inherit pkgs;};
          opencode-lsp-python = lib.mkShell {
            inherit pkgs;
            profiles = ["python"];
          };
          opencode-lsp-pkl = lib.mkShell {
            inherit pkgs;
            profiles = ["pkl"];
            inherit pklLsp;
          };
          default = self.devShells.${system}.opencode-lsp;
        };

        checks = {
          config-base-shape =
            pkgs.runCommand "opencode-lsp-config-base-shape" {
              nativeBuildInputs = [pkgs.jq];
            } ''
              jq -e '
                .lsp.nixd.command[0]
                and .lsp.rust.command[0]
                and .lsp.taplo.command[0]
                and (.lsp.pyright == null)
              ' ${self.packages.${system}.opencode-lsp-config} >/dev/null
              touch "$out"
            '';

          config-python-shape =
            pkgs.runCommand "opencode-lsp-config-python-shape" {
              nativeBuildInputs = [pkgs.jq];
            } ''
              jq -e '
                .lsp.basedpyright.command[0]
                and .lsp.ruff.command[0]
                and (.lsp.pyright.disabled == true)
              ' ${self.packages.${system}.opencode-lsp-config-python} >/dev/null
              touch "$out"
            '';

          config-pkl-shape =
            pkgs.runCommand "opencode-lsp-config-pkl-shape" {
              nativeBuildInputs = [pkgs.jq];
            } ''
              jq -e '
                .lsp.pkl.command[0]
                and (.lsp.pkl.command[1] == "--stdio")
                and (.lsp.pkl.extensions | index(".pkl"))
              ' ${self.packages.${system}.opencode-lsp-config-pkl} >/dev/null
              touch "$out"
            '';

          config-merge-preserves-existing-content =
            pkgs.runCommand "opencode-lsp-config-merge-preserves-existing-content" {
              nativeBuildInputs = [pkgs.jq];
            } ''
              existing='{"model":"demo","lsp":{"custom":{"command":["custom-lsp"],"extensions":[".custom"]}}}'
              merged="$(
                printf '%s' "$existing" \
                  | jq -c --slurpfile opencodeLsp ${self.packages.${system}.opencode-lsp-config-pkl} '
                      . as $existing
                      | $opencodeLsp[0] as $incoming
                      | $existing * $incoming
                      | .lsp = (($existing.lsp // {}) + ($incoming.lsp // {}))
                    '
              )"
              printf '%s' "$merged" | jq -e '
                .model == "demo"
                and .lsp.custom.command[0] == "custom-lsp"
                and .lsp.pkl.command[1] == "--stdio"
              ' >/dev/null
              touch "$out"
            '';

          shellhook-merge =
            pkgs.runCommand "opencode-lsp-shellhook-merge" {
              nativeBuildInputs = [pkgs.bash pkgs.jq];
              inherit (self.devShells.${system}.opencode-lsp) shellHook;
            } ''
              run_hook() { eval "$shellHook"; }

              unset OPENCODE_CONFIG_CONTENT
              run_hook
              printf '%s' "$OPENCODE_CONFIG_CONTENT" | jq -e '.lsp.nixd.command[0] and .lsp.rust.command[0]' >/dev/null

              OPENCODE_CONFIG_CONTENT=""
              run_hook
              printf '%s' "$OPENCODE_CONFIG_CONTENT" | jq -e '.lsp.nixd.command[0]' >/dev/null

              OPENCODE_CONFIG_CONTENT='{"model":"demo","lsp":{"custom":{"command":["custom-lsp"]}}}'
              run_hook
              printf '%s' "$OPENCODE_CONFIG_CONTENT" | jq -e '
                .model == "demo"
                and .lsp.custom.command[0] == "custom-lsp"
                and .lsp.nixd.command[0]
              ' >/dev/null
              first="$OPENCODE_CONFIG_CONTENT"
              run_hook
              test "$OPENCODE_CONFIG_CONTENT" = "$first"

              OPENCODE_CONFIG_CONTENT='not-json'
              if run_hook; then
                echo "expected malformed OPENCODE_CONFIG_CONTENT to fail" >&2
                exit 1
              fi
              test "$OPENCODE_CONFIG_CONTENT" = "not-json"

              touch "$out"
            '';
        };
      }
    );
}
