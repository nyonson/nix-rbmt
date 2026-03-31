{ lib }:

{
  # Merge multiple shell attribute sets into a single shell-compatible set.
  #
  # Each input shell should be a set with `packages` (list) and `env` (attrs) keys,
  # matching the structure expected by mkShell.
  mergeShells = shells:
    {
      packages = lib.unique (lib.concatLists (map (s: s.packages or []) shells));
      env = lib.mergeAttrsList (map (s: s.env or {}) shells);
    };
}
