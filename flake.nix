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
      in {
        packages = {
          opencode-lsp-config = lib.mkConfigPackage {inherit pkgs;};
          opencode-lsp-config-python = lib.mkConfigPackage {
            inherit pkgs;
            profiles = ["python"];
          };
          default = self.packages.${system}.opencode-lsp-config;
        };

        devShells = {
          opencode-lsp = lib.mkShell {inherit pkgs;};
          opencode-lsp-python = lib.mkShell {
            inherit pkgs;
            profiles = ["python"];
          };
          default = self.devShells.${system}.opencode-lsp;
        };

        checks = {
          config-base-shape = pkgs.runCommand "opencode-lsp-config-base-shape" {
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

          config-python-shape = pkgs.runCommand "opencode-lsp-config-python-shape" {
            nativeBuildInputs = [pkgs.jq];
          } ''
            jq -e '
              .lsp.basedpyright.command[0]
              and .lsp.ruff.command[0]
              and (.lsp.pyright.disabled == true)
            ' ${self.packages.${system}.opencode-lsp-config-python} >/dev/null
            touch "$out"
          '';
        };
      }
    );
}
