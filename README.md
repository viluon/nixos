Partition with

```sh
sudo -E `which nix` --extra-experimental-features 'nix-command flakes' run -vL github:nix-community/disko/latest -- --flake .#nixluon --mode destroy,format,mount
```

Install with

```sh
sudo -E `which nix` --extra-experimental-features 'nix-command flakes' run -vL github:nix-community/disko/latest#disko-install -- --flake .#nixluon --disk main <path/to/disk>
```

Build with

```sh
nice -n 19 ionice -c 3 nix build .#nixosConfigurations.nixluon.config.system.build.toplevel
```

Update with

```sh
sudo nice -n 19 ionice -c 3 nixos-rebuild switch --flake .
```

### panic at the disko

`disko-install` may fail with
```
setting up /etc...
/nix/var/nix/profiles/system/sw/bin/bash: line 10: mount: command not found
disko-install failed
```
particularly if you're not already on NixOS.
There's [a Discourse thread](https://discourse.nixos.org/t/nixos-install-mount-command-not-found/59197) about the problem.

TL;DR:
```bash
# mount the (existing) system via just disko
sudo -E `which nix` --extra-experimental-features 'nix-command flakes' run -vL github:nix-community/disko/latest -- --flake .#nixluon --mode mount
# run disko-install in dry run mode to get the system path
sudo -E `which nix` --extra-experimental-features 'nix-command flakes' run -vL github:nix-community/disko/latest#disko-install -- --flake .#nixluon --disk main /dev/sda --dry-run
# grab a nixos-install via comma
, -s nixos-install
# remember where it is
which nixos-install
# go superuser (sudo alone won't work, nix-env won't be found)
sudo su -
# fix path
export PATH="$PATH:/nix/var/nix/profiles/system/sw/bin"
# install (see previous steps for the paths)
<path/to/nixos-install> --system <path/to/system> --root '/mnt/'
```

### inspiration

- [nixos.asia](https://nixos.asia/en/configuration-as-flake)
- [flake.parts](https://flake.parts/module-arguments)
- [rxyhn/yuki](https://github.com/rxyhn/yuki/blob/2fcbd0c1cde5fcd6e2236b0aa90c72629dbb3740/flake.nix)
- the [NixOS & Flakes book](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/nixos-flake-configuration-explained)
- [felschr/nixos-config](https://github.com/felschr/nixos-config)
