{ pkgs, ... }:
let
  cleanupBeforeShutdown = import ../../modules/home/scripts/cleanup-before-shutdown.nix { inherit pkgs; };
in
{
  systemd.user.services.shutdown-reminder = {
    description = "Offer pre-shutdown cleanup";
    path = [ pkgs.libnotify cleanupBeforeShutdown ];
    script = ''
      clicked=$(notify-send --wait --action=default="Clean up" \
        "Time to wrap up" "Click to close idle shells and compact Copilot sessions")
      if [ "$clicked" = default ]; then
        cleanup-before-shutdown
      fi
    '';
  };

  systemd.user.timers.shutdown-reminder = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "Mon..Fri 17:20";
  };
}
