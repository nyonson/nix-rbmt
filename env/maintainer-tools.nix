# Leverage some bitcoin core maintainer tools for dev environment.

{ pkgs
, bitcoin-maintainer-tools ? pkgs.fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "bitcoin-maintainer-tools";
    rev = "3dec1b2561985f53fca7b934a81e713614f0cb87";
    sha256 = "sha256-5Kuc3MQLvFiDnQfxrR5ToBGcXLY4IlNCpl15c/eJgFQ=";
  }
}:

let
  github-merge = pkgs.writeShellScriptBin "github-merge" ''
    exec ${pkgs.python3}/bin/python3 ${bitcoin-maintainer-tools}/github-merge.py "$@"
  '';
in
{
  packages = [ github-merge ];
}
