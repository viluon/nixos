{ config, pkgs, ... }:
let
  # grafana configuration
  services.alloy = {
    enable = true;
  };

  systemd.services.alloy.serviceConfig.TimeoutStopSec = "8s";

  environment.etc."alloy/config.alloy".text = ''
    logging {
      level = "info"
    }

    loki.source.journal "system" {
      forward_to = [loki.process.json.receiver]
      format_as_json = true
      labels = {
        job = "systemd-journal",
        host = "__journal__hostname",
      }
    }

    loki.process "json" {
      forward_to = [loki.write.default.receiver]

      stage.json {
        expressions = {
          level = "PRIORITY",
          unit = "_SYSTEMD_UNIT",
          message = "MESSAGE",
          pid = "_PID",
          comm = "_COMM",
          hostname = "_HOSTNAME",
          boot_id = "_BOOT_ID",
          transport = "_TRANSPORT",
        }
      }

      stage.structured_metadata {
        values = {
          level = "",
          unit = "",
          pid = "",
          comm = "",
          hostname = "",
          boot_id = "",
          transport = "",
        }
      }
    }

    loki.write "default" {
      endpoint {
        url = "http://localhost:${toString lokiPort}/loki/api/v1/push"
      }
    }
  '';

  lokiPort = 3100;
  lokiGrpcPort = 9095;

  grpc_client_config = {
    max_recv_msg_size = 100 * 1024 * 1024;
    max_send_msg_size = 100 * 1024 * 1024;
    grpc_compression = "gzip";
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_port = lokiPort;
        grpc_server_max_recv_msg_size = grpc_client_config.max_recv_msg_size;
        grpc_server_max_send_msg_size = grpc_client_config.max_send_msg_size;
      };

      limits_config = {
        ingestion_rate_mb = 16; # up from default 4MB
        ingestion_burst_size_mb = 32; # larger burst size
        per_stream_rate_limit = "16MB";
        per_stream_rate_limit_burst = "32MB";
        retention_period = "365d"; # keep logs for 1 year
        volume_enabled = true;
      };

      ingester_client = {
        inherit grpc_client_config;
      };

      query_scheduler = {
        inherit grpc_client_config;
      };

      frontend = {
        inherit grpc_client_config;
      };

      frontend_worker = {
        inherit grpc_client_config;
      };

      common = {
        instance_addr = "::0";
        ring = {
          instance_port = lokiGrpcPort;
          kvstore.store = "inmemory";
        };
        replication_factor = 1;
        path_prefix = "/var/lib/loki";
      };

      schema_config = {
        configs = [{
          from = "2020-05-15";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        filesystem.directory = "/var/lib/loki/chunks";
      };
    };

    dataDir = "/var/lib/loki";
  };

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
          {
            name = "local loki";
            type = "loki";
            uid = "loki-local";
            url = "http://localhost:${toString lokiPort}";
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
      proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
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
          "ethtool"
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

  networking.firewall.allowedTCPPorts = [ lokiPort lokiGrpcPort ];
in
{
  inherit services environment networking;
}
