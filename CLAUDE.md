
- In all interactions and commit messages, be extremely concise and sacrifice grammar for brevity.

## Repository Overview

This is a personal NixOS configuration using flakes and home-manager. The repository manages two hosts (`nixluon` - Framework AMD AI 300, `nixboerse` - ThinkPad P1 Gen 3) with modular system and home configurations. It uses flake-parts for organization and includes custom packages, scripts, and desktop environment configurations.

## Style Guidelines

Use comments only very sparingly. Always prefer clear variable names and split into smaller helper functions and Nix expressions over comments. The only place for comments is in code that is too dense and cannot be refactored further towards clarity.

## Edit-Compile-Run Loop

```bash
just test      # Apply config temporarily (no reboot needed)
just switch    # Apply config permanently
just run-vm    # Test in VM (builds automatically, SSH: localhost:2222)
just format    # Format before committing
```

Run `just` to see all available commands.

**VM tips**: Reset VM state with `rm $(hostname).qcow2`. Use `virtualisation.vmVariant` for VM-specific config.

## Architecture

### Flake Structure

The flake uses **flake-parts** to organize outputs. Key elements:

- `flake.nix`: Main entry point, defines inputs, hosts, and orchestrates the build
- Denix constructs NixOS and Home Manager configurations from `denix/`
- Custom flake modules use `importApply` when they need `withSystem`

### Host Configurations

Each host in `denix/hosts/<hostname>/`:
- `default.nix`: Main configuration
- `hardware.nix`: Auto-generated hardware settings
- `kernel.nix`: Custom kernel patches
- `disko.nix`: Disk partitioning (nixluon)
- `nvidia.nix`: GPU config (nixboerse)

### Module Organization

- `denix/modules/system/`: nix, networking, systemd, monitoring
- `denix/modules/hardware/`: audio, graphics
- `denix/modules/desktop/`: GNOME, Niri, Stylix
- `denix/modules/editors/`: Neovim, VSCode, IntelliJ
- `denix/modules/core/user.nix`: User config
- `denix/modules/home/`: Home Manager config and scripts

### Package Overlays

Custom packages in `packages/` (overlay applied in flake.nix:82-86):
- `linux-entra-sso`: Enterprise SSO with browser native messaging
- `amd-epp-tool`: AMD EPP control

### Home-Manager Integration

Integrated at NixOS level (flake.nix:72-80). Users auto-generated from `home/` dirs. `extraSpecialArgs` provides `inputs`, `hostname`, `unstable-pkgs` to home modules.

### Desktop Environments

**GNOME** (default, dconf + extensions per-host) and **Niri** (scrollable tiling). Both use **Stylix** (Catppuccin Mocha).

### Special Features

**vmVariant**: Auto-login, SSH on 2222, passwordless, KVM+GTK, 2 cores/4GB RAM.

**Git Scripts**: `denix/modules/home/scripts/git-*.nix` exposed as git subcommands with zsh completion.

**Binary Caches**: cache.nixos.org, nix-community.cachix.org, viluon.cachix.org (`denix/modules/system/nix.nix`).

## Development Environment

DevShell (flake.nix:136-146): `treefmt`, `just`, `nvd`. Enter with `nix develop` or `direnv`.

## Key Patterns

1. **Host-specific**: Use `hostname` arg in modules/home configs
2. **Unstable packages**: `unstable-pkgs` in modules, `inputs.nixpkgs-unstable.legacyPackages.${system}` in home
3. **Custom scripts**: `denix/modules/home/scripts/*.nix` → PATH commands
4. **Modules**: System in `modules/`, home in user `home.nix`
5. **Before commit**: `just format`

## Important Details

**SSH**: Passwordless auth with GitHub API keys (fixed hash for reproducibility), configured in `denix/modules/core/user.nix`.

**Virtualization** (nixboerse): libvirtd with DNS routing hooks, Docker+minikube/kind firewall rules.

**Hardware**: NVIDIA (nixboerse), Intel graphics (nixboerse), AMD optimizations (nixluon via nixos-hardware).

**User**: `viluon` with sudo, passwordless `nixos-rebuild test`.

**Pitfalls**: VM networking uses `forwardPorts` not manual netdev; libvirtd hooks need `restartTriggers`; kernel options use `lib.kernel.yes`.
