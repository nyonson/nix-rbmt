# Rust Bitcoin Maintainer Tools for Nix

Composable Nix modules and environments for rust-bitcoin development.

* `env` // Shell environment definitions.
* `lib` // Shared library functions.
* `modules` // NixOS modules.

While functionality is exported through the top level [flake.nix](./flake.nix) which also pins inputs, it is by no means necessary to use the flake. Ideally, logic is defined in the lower level [library directory](./lib) and can be dependend upon by any nix method.
