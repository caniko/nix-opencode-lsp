{nixpkgs}: let
  inherit (nixpkgs) lib;

  profileEnabled = profiles: profile: builtins.elem profile profiles;
  defaultPklLspHashes = {
    linux-x64 = "sha256-hNrY6TXbC7zVZbPj1/VazvYyG6sUXSwJMSdQMEUrmjg=";
    linux-arm64 = "sha256-pdtU4nJW8JifpKV362y0MCPXbQ0PqVETGrIr2MfU6JY=";
    darwin-x64 = "sha256-1Of1OfnKD1kSVjuFqm9bzorWVLrZN2sCEn7VSMN1Reg=";
    darwin-arm64 = "sha256-ceTKsmrZAmb2Sal/Nyfb1Dj8T+EFozimLH1kWNQmkHU=";
  };
in rec {
  mkPklLspReleasePackage = {
    pkgs,
    version ? "0.1.0",
    hashes ? defaultPklLspHashes,
    owner ? "caniko",
    repo ? "pkl-lsp",
  }: let
    targetForSystem = {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      x86_64-darwin = "darwin-x64";
      aarch64-darwin = "darwin-arm64";
    };
    system = pkgs.stdenv.hostPlatform.system;
    target =
      targetForSystem.${system}
      or (throw "pkl-lsp release assets are not available for ${system}");
    extension =
      if lib.hasPrefix "win32-" target
      then "zip"
      else "tar.gz";
    executable =
      if lib.hasPrefix "win32-" target
      then "pkl-lsp.exe"
      else "pkl-lsp";
  in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "pkl-lsp";
      inherit version;
      src = pkgs.fetchurl {
        url = "https://codeberg.org/${owner}/${repo}/releases/download/${version}/pkl-lsp-${version}-${target}.${extension}";
        hash =
          hashes.${target}
          or (throw "missing pkl-lsp release hash for ${target}");
      };
      unpackPhase = ''
        runHook preUnpack
        tar -xzf "$src"
        runHook postUnpack
      '';
      installPhase = ''
        mkdir -p "$out/bin"
        cp "${executable}" "$out/bin/${executable}"
        chmod 0755 "$out/bin/${executable}"
        ${
          lib.optionalString (executable != "pkl-lsp") ''
            ln -s "$out/bin/${executable}" "$out/bin/pkl-lsp"
          ''
        }
      '';
    };

  mkServers = {
    pkgs,
    profiles ? [],
    rustAnalyzer ? pkgs.rust-analyzer,
    pklLsp ? null,
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

    pklLspConfig = lib.optionalAttrs (profileEnabled profiles "pkl") {
      pkl = {
        command = ["${pklLsp}/bin/pkl-lsp" "--stdio"];
        extensions = [".pkl"];
      };
    };
  in
    baseLsp // pythonLsp // pklLspConfig // extraLsp;

  mkLspConfig = {servers}: {lsp = servers;};

  mkLspConfigPackage = {
    pkgs,
    servers,
  }:
    pkgs.writeText "opencode-lsp-config.json" (builtins.toJSON (mkLspConfig {inherit servers;}));

  mkLspShell = {
    pkgs,
    servers,
    extraShellHook ? "",
    packages ? [],
  }: let
    config = mkLspConfigPackage {inherit pkgs servers;};
  in
    pkgs.mkShell {
      packages = [pkgs.jq] ++ packages;
      shellHook = ''
        existing="''${OPENCODE_CONFIG_CONTENT:-"{}"}"
        merged="$(${pkgs.jq}/bin/jq -cn --argjson existing "$existing" --slurpfile incoming ${config} '
          $existing * $incoming[0]
          | .lsp = (($existing.lsp // {}) + ($incoming[0].lsp // {}))
        ')" || return 1
        export OPENCODE_CONFIG_CONTENT="$merged"
        ${extraShellHook}
      '';
    };

  mkConfig = args:
    mkLspConfig {servers = mkServers args;};

  mkConfigPackage = {
    pkgs,
    profiles ? [],
    rustAnalyzer ? pkgs.rust-analyzer,
    pklLsp ? null,
    extraLsp ? {},
  }:
    assert !profileEnabled profiles "pkl" || pklLsp != null;
      mkLspConfigPackage {
        inherit pkgs;
        servers = mkServers {
          inherit pkgs profiles rustAnalyzer pklLsp extraLsp;
        };
      };

  mkShell = {
    pkgs,
    profiles ? [],
    rustAnalyzer ? pkgs.rust-analyzer,
    pklLsp ? null,
    extraLsp ? {},
    extraPackages ? [],
    extraShellHook ? "",
  }: let
    pythonPackages = lib.optionals (profileEnabled profiles "python") [
      pkgs.basedpyright
      pkgs.ruff
    ];
    pklPackages = lib.optionals (profileEnabled profiles "pkl") [pklLsp];
  in
    assert !profileEnabled profiles "pkl" || pklLsp != null;
      mkLspShell {
        inherit pkgs extraShellHook;
        servers = mkServers {
          inherit pkgs profiles rustAnalyzer pklLsp extraLsp;
        };
        packages =
          [
            pkgs.nixd
            pkgs.taplo
            rustAnalyzer
          ]
          ++ pythonPackages
          ++ pklPackages
          ++ extraPackages;
      };
}
