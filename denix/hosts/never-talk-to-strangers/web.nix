{ delib, ... }:
let
  cloudflareRanges = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];

  staticSite = root: {
    enableACME = true;
    forceSSL = true;
    inherit root;
    extraConfig = "error_page 404 /404.html;";
  };
in
delib.host {
  name = "never-talk-to-strangers";

  nixos.imports = [
    (
      { lib, ... }:
      {
        networking.firewall.allowedTCPPorts = [ 80 443 ];

        security.acme.acceptTerms = true;

        services.nginx = {
          enable = true;
          recommendedTlsSettings = true;
          recommendedOptimisation = true;
          recommendedGzipSettings = true;
          recommendedProxySettings = true;

          commonHttpConfig = ''
            ${lib.concatMapStrings (range: "set_real_ip_from ${range};\n") cloudflareRanges}
            real_ip_header CF-Connecting-IP;

            geo $realip_remote_addr $via_cloudflare {
              default 0;
              ${lib.concatMapStrings (range: "${range} 1;\n") cloudflareRanges}
            }
          '';

          virtualHosts = {
            "_" = {
              default = true;
              rejectSSL = true;
              locations."/".return = "444";
            };

            "cc.viluon.me" = staticSite "/srv/www/cc";
            "copy-cat.viluon.me" = staticSite "/srv/www/copy-cat";

            "cloud-catcher.viluon.me" = lib.recursiveUpdate (staticSite "/srv/www/cloud-catcher") {
              locations."~ /(view|connect|host|cloud\\.lua)" = {
                proxyPass = "http://localhost:8080";
                proxyWebsockets = true;
              };
            };

            "ntts.viluon.me" = {
              enableACME = true;
              forceSSL = true;
              locations."/".return = "404";
            };

            "grocy.viluon.me".extraConfig = ''
              if ($via_cloudflare = 0) {
                return 444;
              }
            '';
          };
        };
      }
    )
  ];
}
