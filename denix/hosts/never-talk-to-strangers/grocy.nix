{ delib, ... }:
delib.host {
  name = "never-talk-to-strangers";

  nixos.imports = [
    (
      { config, ... }:
      {
        services.grocy = {
          enable = true;
          hostName = "grocy.viluon.me";

          settings = {
            currency = "CZK";
            calendar = {
              firstDayOfWeek = 1;
              showWeekNumber = true;
            };
          };

          phpfpm.settings = {
            "pm" = "ondemand";
            "pm.max_children" = 4;
            "pm.process_idle_timeout" = "60s";
            "pm.max_requests" = 500;
            "php_admin_value[error_log]" = "stderr";
            "php_admin_flag[log_errors]" = true;
            "listen.owner" = config.services.nginx.user;
            "catch_workers_output" = true;
          };
        };

        services.phpfpm.pools.grocy.phpOptions = ''
          session.upload_progress.enabled = Off
        '';

        systemd.tmpfiles.rules = [ "Z ${config.services.grocy.dataDir} - grocy nginx - -" ];
      }
    )
  ];
}
