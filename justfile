# list recipes
default:
    just --list

format:
    treefmt

check:
    nix flake check -L

build:
    nice -n 19 ionice -c 3 nix build -L .#nixosConfigurations.$(hostname).config.system.build.toplevel

# build & apply on the next boot
boot:
    sudo nice -n 19 ionice -c 3 nixos-rebuild boot -L --flake .

# build & apply now and on the next boot
switch:
    sudo nice -n 19 ionice -c 3 nixos-rebuild switch -L --flake .

# build & apply but only for now
test:
    sudo nixos-rebuild test -L --flake $(pwd)

build-vm:
    nixos-rebuild build-vm -L --flake .

run-vm: build-vm
    result/bin/run-$(hostname)-vm

# recompress the disk image
optimise-disk:
    qemu-img convert -p -c -o compression_type=zstd -m 16 -O qcow2 $(hostname).qcow2 $(hostname).c.qcow2 && mv $(hostname).c.qcow2 $(hostname).qcow2
