# Rust fuzzing tooling environment (cargo-fuzz and dependencies).

{ pkgs }:

{
  # Required packages.
  packages = [
    pkgs.cargo-fuzz
    pkgs.stdenv.cc
  ];

  # Environment variables.
  env = {
    # cargo-fuzz compiles binaries at runtime (outside Nix's control), so those
    # binaries don't get Nix's automatic library path patching. We work around
    # this with LD_LIBRARY_PATH for the C++ standard library.
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
  };
}
