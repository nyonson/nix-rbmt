# Notification utility functions.

{ pkgs }:

{
  # Creates a shell script that sends email notification.
  mkEmailNotification = { email, subject, body }:
    pkgs.writeShellScript "send-email" ''
      set -euo pipefail
      
      (
        echo "To: ${email}"
        echo "Subject: ${subject}"
        echo ""
        echo "${body}"
      ) | ${pkgs.system-sendmail}/bin/sendmail -i -t
    '';
}
