{
  description = "Rust Bitcoin Maintainer Tools for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bitcoin-maintainer-tools = {
      url = "github:bitcoin-core/bitcoin-maintainer-tools";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, fenix, bitcoin-maintainer-tools }: {
      nixosModules = {
        fuzzing = import ./modules/fuzzing.nix;

        default = { pkgs, ... }: {
          imports = [ self.nixosModules.fuzzing ];
          services.cargo-fuzz.nightlyToolchain = fenix.packages.${pkgs.system}.minimal.toolchain;
        };
      };

      devShells = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in {
            fuzzing = pkgs.mkShell (import ./env/fuzzing.nix { inherit pkgs; });
            maintainer-tools = pkgs.mkShell (import ./env/maintainer-tools.nix {
              inherit pkgs bitcoin-maintainer-tools;
            });
            rust = pkgs.mkShell (import ./env/rust.nix { inherit pkgs; });
            default = pkgs.mkShell (import ./env/rust.nix { inherit pkgs; });
          }
        );
    };
}
