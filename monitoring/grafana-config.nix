{ config, pkgs, ... }: {
  # grafana configuration
  services.grafana = {
    enable = true;
    settings = {
      server = {
        domain = "localhost";
        http_port = 2342;
        http_addr = "127.0.0.1";
      };
    };
    provision =
      let
        # see https://grafana.com/tutorials/provision-dashboards-and-data-sources/#define-a-dashboard-provider
        dashboard-providers = [
          {
            name = "provisoned nixluon central";
            type = "file";
            allowUiUpdates = true;
            options.path = ./nixluon-central.json;
          }
        ];
        datasource-providers = [
          {
            name = "local prometheus";
            type = "prometheus";
            uid = "prometheus-local";
            url = "http://localhost:${toString config.services.prometheus.port}";
            jsonData = {
              incrementalQuerying = true;
            };
          }
        ];
      in
      {
        enable = true;

        dashboards.settings = {
          apiVersion = 1;
          providers = dashboard-providers;
        };

        datasources.settings = {
          apiVersion = 1;
          datasources = datasource-providers;
        };
      };
  };

  # nginx reverse proxy
  services.nginx.virtualHosts.${config.services.grafana.domain} = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
      proxyWebsockets = true;
    };
  };

  services.prometheus = {
    enable = true;
    port = 9001;

    retentionTime = "365d";

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [
          "hwmon"
        ];
        port = 9002;
      };

      smartctl = {
        enable = true;
        port = 9003;
      };

      systemd = {
        enable = true;
        port = 9004;
      };
    };

    globalConfig = {
      scrape_interval = "20s";
    };

    scrapeConfigs = [
      {
        job_name = "chrysalis";
        static_configs = [{
          targets = [
            "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
            "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}"
            "127.0.0.1:${toString config.services.prometheus.exporters.systemd.port}"
          ];
        }];
      }
    ];
  };
}
