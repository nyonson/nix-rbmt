# Git utility functions

{ pkgs }:

{
  # Creates a shell script derivation that performs shallow git checkout or
  # updates to the most recent upstream commit if available.
  mkShallowCheckout = { repo, ref, targetDir }:
    pkgs.writeShellScript "git-shallow-checkout" ''
      set -euo pipefail

      TARGET_DIR="${targetDir}"

      if [ ! -d "$TARGET_DIR/.git" ]; then
        ${pkgs.git}/bin/git clone --depth 1 --revision ${ref} ${repo} "$TARGET_DIR"
      else
        cd "$TARGET_DIR"
        ${pkgs.git}/bin/git fetch --depth 1 origin ${ref}
        ${pkgs.git}/bin/git checkout FETCH_HEAD
      fi
    '';
}
