{ delib, ... }:
delib.module {
  name = "system.containerNetworking";

  options.system.containerNetworking = with delib; {
    enable = boolOption false;
    uplinkInterface = strOption "wlp9s0";
    vmName = strOption "ubuntu";
    splitDnsServer = strOption "100.64.0.2";
    splitDnsDomains = listOfOption str [ ];
  };

  nixos.always = { cfg, ... }: {
    imports = [
      (
        { config, lib, pkgs, ... }:
        let
          dockerBridgeDns = "172.17.0.1";
          dockerSubnet = "172.17.0.0/16";
          minikubeSubnet = "192.168.49.0/24";
          kindSubnet = "172.18.0.0/16";

          forwardRules = [
            "-s ${dockerSubnet} ! -i ${cfg.uplinkInterface} -o virbr0 -j ACCEPT"
            "-s ${minikubeSubnet} ! -i ${cfg.uplinkInterface} -o virbr0 -j ACCEPT"
            "-s ${kindSubnet} ! -i ${cfg.uplinkInterface} -o virbr0 -j ACCEPT"
            "-i virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
          ];
        in
        lib.mkIf cfg.enable {
          programs.virt-manager.enable = true;

          virtualisation.libvirtd = {
            enable = true;
            qemu.package = pkgs.qemu_kvm;
            hooks.qemu.libvirtd-network-hook = pkgs.writeShellScript "libvirtd-network-hook" ''
              set -euo pipefail

              case $1:$2 in
                ${cfg.vmName}:start)
                  ${pkgs.systemd}/bin/resolvectl dns virbr0 ${cfg.splitDnsServer}
                  ${pkgs.systemd}/bin/resolvectl domain virbr0 ${builtins.concatStringsSep " " cfg.splitDnsDomains}
                  ${pkgs.systemd}/bin/resolvectl default-route virbr0 no
                  ${pkgs.systemd}/bin/resolvectl dnsovertls virbr0 no
                  ;;
              esac
            '';
          };

          systemd.services.libvirtd = {
            restartTriggers = [ config.virtualisation.libvirtd.hooks.qemu.libvirtd-network-hook ];
            serviceConfig.TimeoutStopSec = 8;
          };

          services.resolved.settings.Resolve.DNSStubListenerExtra = dockerBridgeDns;

          systemd.services.resume-ubuntu-vm = {
            description = "Resume Ubuntu VM snapshot";
            after = [ "libvirtd.service" "libvirt-guests.service" ];
            requires = [ "libvirtd.service" ];
            wantedBy = [ "multi-user.target" ];
            restartIfChanged = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.writeShellScript "resume-ubuntu-vm" ''
                set -euo pipefail
                ${config.virtualisation.libvirtd.package}/bin/virsh snapshot-revert ${cfg.vmName} --current
                ${config.virtualisation.libvirtd.package}/bin/virsh resume ${cfg.vmName}
              ''}";
              ExecStop = "${pkgs.writeShellScript "destroy-ubuntu-vm" ''
                ${config.virtualisation.libvirtd.package}/bin/virsh destroy ${cfg.vmName} || true
              ''}";
            };
          };

          networking.firewall = {
            extraCommands = lib.mkAfter ''
              # Allow Docker/kind containers to reach host's resolved stub on docker0
              iptables -I nixos-fw -d ${dockerBridgeDns} -p udp --dport 53 -j nixos-fw-accept
              iptables -I nixos-fw -d ${dockerBridgeDns} -p tcp --dport 53 -j nixos-fw-accept
            '';
            extraStopCommands = ''
              iptables -D nixos-fw -d ${dockerBridgeDns} -p udp --dport 53 -j nixos-fw-accept || true
              iptables -D nixos-fw -d ${dockerBridgeDns} -p tcp --dport 53 -j nixos-fw-accept || true
            '';
          };

          systemd.services.firewall-virbr0-bypass = {
            description = "Re-insert FORWARD ACCEPT rules above libvirt/docker chains";
            wantedBy = [ "multi-user.target" ];
            after = [ "docker.service" "libvirtd.service" "firewall.service" ];
            requires = [ "firewall.service" ];
            partOf = [ "firewall.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              ${lib.concatMapStringsSep "\n" (rule: ''
                ${pkgs.iptables}/bin/iptables -D FORWARD ${rule} 2>/dev/null || true
                ${pkgs.iptables}/bin/iptables -I FORWARD 1 ${rule}
              '') forwardRules}
            '';
            preStop = ''
              ${lib.concatMapStringsSep "\n" (rule: ''
                ${pkgs.iptables}/bin/iptables -D FORWARD ${rule} 2>/dev/null || true
              '') forwardRules}
            '';
          };

          boot.kernel.sysctl = {
            "net.bridge.bridge-nf-call-iptables" = 0;
            "net.bridge.bridge-nf-call-ip6tables" = 0;
          };

          virtualisation.docker = {
            enable = true;
            daemon.settings.dns = [ dockerBridgeDns ];
          };
        }
      )
    ];
  };
}
