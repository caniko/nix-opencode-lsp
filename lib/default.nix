{nixpkgs}: let
  inherit (nixpkgs) lib;

  profileEnabled = profiles: profile: builtins.elem profile profiles;
in rec {
  mkConfig = {
    pkgs,
    profiles ? [],
    rustAnalyzer ? pkgs.rust-analyzer,
    extraLsp ? {},
  }: let
    baseLsp = {
      nixd.command = ["${pkgs.nixd}/bin/nixd"];
      rust.command = ["${rustAnalyzer}/bin/rust-analyzer"];
      taplo = {
        command = ["${pkgs.taplo}/bin/taplo" "lsp" "stdio"];
        extensions = [".toml"];
      };
    };

    pythonLsp = lib.optionalAttrs (profileEnabled profiles "python") {
      basedpyright = {
        command = ["${pkgs.basedpyright}/bin/basedpyright-langserver" "--stdio"];
        extensions = [".py" ".pyi"];
      };
      pyright.disabled = true;
      ruff = {
        command = ["${pkgs.ruff}/bin/ruff" "server"];
        extensions = [".py" ".pyi"];
      };
    };
  in {
    "$schema" = "https://opencode.ai/config.json";
    lsp = baseLsp // pythonLsp // extraLsp;
  };

  mkConfigPackage = {
    pkgs,
    profiles ? [],
    rustAnalyzer ? pkgs.rust-analyzer,
    extraLsp ? {},
  }:
    pkgs.writeText "opencode-lsp-config.json" (builtins.toJSON (mkConfig {
      inherit pkgs profiles rustAnalyzer extraLsp;
    }));

  mkShell = {
    pkgs,
    profiles ? [],
    rustAnalyzer ? pkgs.rust-analyzer,
    extraLsp ? {},
    extraPackages ? [],
    extraShellHook ? "",
  }: let
    configFile = mkConfigPackage {
      inherit pkgs profiles rustAnalyzer extraLsp;
    };
    pythonPackages = lib.optionals (profileEnabled profiles "python") [
      pkgs.basedpyright
      pkgs.ruff
    ];
  in
    pkgs.mkShellNoCC {
      packages =
        [
          pkgs.jq
          pkgs.nixd
          pkgs.taplo
          rustAnalyzer
        ]
        ++ pythonPackages
        ++ extraPackages;

      shellHook = ''
        __opencode_lsp_config=${configFile}
        if [ -n "''${OPENCODE_CONFIG_CONTENT:-}" ]; then
          OPENCODE_CONFIG_CONTENT="$(
            printf '%s' "$OPENCODE_CONFIG_CONTENT" \
              | ${pkgs.jq}/bin/jq -c --slurpfile opencodeLsp "$__opencode_lsp_config" '
                  . as $existing
                  | $opencodeLsp[0] as $incoming
                  | $existing * $incoming
                  | .lsp = (($existing.lsp // {}) + ($incoming.lsp // {}))
                '
          )"
        else
          OPENCODE_CONFIG_CONTENT="$(${pkgs.coreutils}/bin/cat "$__opencode_lsp_config")"
        fi

        export OPENCODE_CONFIG_CONTENT
        export OPENCODE_DISABLE_LSP_DOWNLOAD=true
        export OPENCODE_EXPERIMENTAL_LSP_TOOL=true
        unset __opencode_lsp_config

        ${extraShellHook}
      '';
    };
}
