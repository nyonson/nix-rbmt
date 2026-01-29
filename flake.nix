{
  description = "Rust Bitcoin Maintainer Tools for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, fenix }: {
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
          in rec {
            fuzzing = pkgs.mkShell (import ./env/fuzzing.nix { inherit pkgs; });
            rust = pkgs.mkShell (import ./env/rust.nix { inherit pkgs; });

            default = pkgs.mkShell {
              inputsFrom = [ fuzzing rust ];
            };
          }
        );
    };
}
