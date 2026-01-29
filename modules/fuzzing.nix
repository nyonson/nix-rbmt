# Continuous fuzzing service for rust projects using cargo-fuzz.
#
# ## Nightly Toolchain Setup
#
# cargo-fuzz requires a nightly rust toolchain, but there isn't a version
# in the standard nixpkgs. A common approach is to overlay the packages
# with a nightly one and then point this module's `nightlyToolchain` arg
# to it.
#
# Popular rust package projects [fenix](https://github.com/nix-community/fenix)
# and [rust-overlay](https://github.com/oxalica/rust-overlay) already exports
# overlays for this purpose.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cargo-fuzz;
  fuzzEnv = import ../env/fuzzing.nix { inherit pkgs; };
  gitLib = import ../lib/git.nix { inherit pkgs; };
  notifyLib = import ../lib/notify.nix { inherit pkgs; };
in {
  options.services.cargo-fuzz = {
    enable = mkEnableOption "cargo-fuzz continuous fuzzing services";

    nightlyToolchain = mkOption {
      type = types.package;
      description = ''
        Nightly Rust toolchain for cargo-fuzz.

        cargo-fuzz requires nightly Rust to enable unstable compiler features.
        Recommended: use fenix overlay and set to pkgs.fenix.minimal.toolchain
      '';
      example = literalExpression "pkgs.fenix.minimal.toolchain";
    };

    email = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to send email notifications on fuzzing failures.

          When enabled, failure notifications are sent to the configured address.
          Requires a system sendmail implementation (e.g., msmtp).
        '';
      };

      address = mkOption {
        type = types.str;
        default = "root";
        description = ''
          Email address or alias to send failure notifications to.

          Defaults to "root" following Unix convention. Configure system email
          aliases (e.g., via programs.msmtp or /etc/aliases) to route root mail
          to your actual email address.

          Requires sendmail to be available at /run/wrappers/bin/sendmail.
          Configure this by enabling programs.msmtp.setSendmail or similar.
        '';
        example = "admin@example.com";
      };
    };

    projects = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          repo = mkOption {
            type = types.str;
            description = ''
              Git repository URL to clone.
            '';
            example = "https://github.com/rust-bitcoin/rust-bip324.git";
          };

          ref = mkOption {
            type = types.str;
            description = ''
              Git ref (branch, tag, or commit) to checkout.
            '';
            example = "master";
          };

          targets = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                cpuQuota = mkOption {
                  type = types.str;
                  default = "80%";
                  description = ''
                    CPU quota for this fuzz target.

                    Maps to systemd's CPUQuota setting, which limits CPU time as a
                    percentage of one CPU core. 200% would be two cores.

                    This prevents a single fuzz target from monopolizing system CPU,
                    allowing multiple targets to run concurrently without starving
                    each other or other system processes.
                  '';
                  example = "150%";
                };

                memoryMax = mkOption {
                  type = types.str;
                  default = "4G";
                  description = ''
                    Maximum memory (RAM) this fuzz target can use.

                    Maps to systemd's MemoryMax setting, which hard-limits the memory
                    available to the service. If the fuzzer tries to allocate more,
                    the kernel's OOM killer will terminate it, and systemd will
                    automatically restart it (due to Restart=always).

                    This prevents memory leaks or pathological test cases from
                    consuming all system memory and causing system instability.
                  '';
                  example = "8G";
                };
              };
            });
            default = {};
            description = ''
              Fuzz targets to run for this project.

              The attribute name (key) is the actual cargo-fuzz target name.
              Use underscores in the key to match the fuzz target filename.

              For example, if you have fuzz/fuzz_targets/receive_key.rs,
              use "receive_key" as the attribute name.

              Each target can override cpuQuota (default: "80%") and memoryMax
              (default: "4G"). An empty attribute set uses all defaults.
            '';
            example = literalExpression ''
              {
                receive_key = {
                  cpuQuota = "50%";
                  memoryMax = "2G";
                };
                receive_garbage = {};
              }
            '';
          };
        };
      });
      default = {};
      description = "Fuzzing projects with their targets";
    };
  };

  config = mkIf cfg.enable {
    users.users.fuzz = {
      isSystemUser = true;
      group = "fuzz";
      home = "/var/lib/fuzz";
      createHome = true;
    };
    users.groups.fuzz = {};

    systemd.services =
      let
        notifyService = optionalAttrs cfg.email.enable {
          "cargo-fuzz-notify@" = {
            description = "Send email notification for failed cargo-fuzz service";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = notifyLib.mkEmailNotification {
                email = cfg.email.address;
                subject = "Fuzzing failure: %i";
                body = "Service %i has failed. Check systemd logs for details.";
              };
            };
          };
        };

        allTargets = flatten (
          mapAttrsToList (projectName: project:
            mapAttrsToList (targetName: target: {
              inherit projectName targetName target project;
            }) project.targets
          ) cfg.projects
        );

        targetToService = { projectName, targetName, target, project }:
          nameValuePair "cargo-fuzz-${projectName}-${targetName}" ({
            description = "Continuous fuzzing: ${projectName}/${targetName}";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            # cargo-fuzz needs rust toolchain and C/C++ compiler to build fuzz targets.
            path = [ cfg.nightlyToolchain ] ++ fuzzEnv.packages;
          } // optionalAttrs cfg.email.enable {
            onFailure = [ "cargo-fuzz-notify@%n.service" ];
          } // {
            serviceConfig = {
              Type = "simple";
              User = "fuzz";
              Group = "fuzz";
              # A shallow clone of the code under test is created in the
              # state directory and is where fuzzing happens.
              StateDirectory = "fuzz/${projectName}/${targetName}";
              WorkingDirectory = "%S/fuzz/${projectName}/${targetName}";
              Restart = "always";
              RestartSec = "5min";
              CPUQuota = target.cpuQuota;
              MemoryMax = target.memoryMax;
              Environment = mapAttrsToList (name: value: "${name}=${value}") fuzzEnv.env;

              ExecStartPre = gitLib.mkShallowCheckout {
                repo = project.repo;
                ref = project.ref;
                targetDir = "$STATE_DIRECTORY";
              };

              ExecStart = "${pkgs.cargo-fuzz}/bin/cargo-fuzz run ${targetName}";
            };
          });
      in
        notifyService // listToAttrs (map targetToService allTargets);
  };
}
