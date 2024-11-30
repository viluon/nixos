Build with

```
nice -n 19 ionice -c 3 nix build .#nixosConfigurations.nixluon.config.system.build.toplevel
```

Update with

```sh
sudo nice -n 19 ionice -c 3 nixos-rebuild switch --flake .
```

### inspiration

- [nixos.asia](https://nixos.asia/en/configuration-as-flake)
- [flake.parts](https://flake.parts/module-arguments)
- [rxyhn/yuki](https://github.com/rxyhn/yuki/blob/2fcbd0c1cde5fcd6e2236b0aa90c72629dbb3740/flake.nix)
- the [NixOS & Flakes book](https://nixos-and-flakes.thiscute.world/nixos-with-flakes/nixos-flake-configuration-explained)
