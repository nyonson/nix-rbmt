# Rust development environment (rustup-based).

{ pkgs }:

{
  # Required packages.
  packages = [
    pkgs.rustup
    # For crates that require external system libraries.
    pkgs.pkg-config
    pkgs.openssl
    # ARM cross-compiler for no_std testing.
    pkgs.gcc-arm-embedded
  ];

  # Environment variables.
  env = {
    # Set ARM cross-compiler for no_std targets.
    CC_thumbv7m_none_eabi = "${pkgs.gcc-arm-embedded}/bin/arm-none-eabi-gcc";
  };
}
