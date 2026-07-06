{ delib, ... }:
delib.module {
  name = "system.sysctl";

  nixos.always.boot.kernel.sysctl = {
    "kernel.sysrq" = 502;
    "kernel.perf_event_paranoid" = 1;
    "kernel.kptr_restrict" = 0;
    "fs.inotify.max_user_watches" = 1048576;
  };
}
