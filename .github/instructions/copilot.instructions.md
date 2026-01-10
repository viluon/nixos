---
applyTo: **
---

# NixOS Flake Configuration - AI Coding Guidelines

## Architecture Overview

This is a **flake-based NixOS configuration** managing multiple hosts with a modular structure:

- **Hosts**: `nixluon` (Framework AMD AI 300), `nixboerse` (ThinkPad P1 Gen 3)
- **Flake structure**: Uses `flake-parts` for organization, imports hardware profiles from `nixos-hardware`
- **Module system**: Reusable components in `modules/` covering desktop, hardware, editors, system, users
- **Home Manager**: Integrated for user-level configuration in `home/`
- **Custom packages**: Overlay system in `packages/` (e.g., `linux-entra-sso`)

## Style

Use comments only very sparingly. Always prefer clear variable names and split into smaller helper functions and Nix expressions over comments. The only place for comments is in code that is too dense and cannot be refactored further towards clarity.

## Key Development Workflows

### Edit-Compile-Run Loop
```bash
just test      # Apply config temporarily (no reboot needed)
just switch    # Apply config permanently
just run-vm    # Test in VM (builds automatically, SSH: localhost:2222)
just format    # Format before committing
```

Run `just` to see all available commands.

**VM tips**: Reset state with `rm $(hostname).qcow2`. Use `virtualisation.vmVariant` for VM-specific config.

## NixOS-Specific Patterns

### Host Configuration Structure
Each host in `hosts/*/`: `default.nix`, `hardware.nix`, `kernel.nix`, `disko.nix` (nixluon), `nvidia.nix` (nixboerse).

### Module Organization
- `modules/system/`: nix, networking, systemd, monitoring
- `modules/hardware/`: audio, graphics
- `modules/desktop/`: GNOME, Niri, Stylix
- `modules/editors/`: Neovim, VSCode, IntelliJ
- `modules/users/common.nix`: User config (SSH keys from GitHub API)
- `home/`: Auto-discovered, scripts in `home/viluon/scripts/` become PATH commands

### Key Details
- **Flake inputs**: nixpkgs 25.11, nixpkgs-unstable, nixos-hardware, stylix, niri
- **Binary caches**: cache.nixos.org, nix-community.cachix.org, viluon.cachix.org
- **Git scripts**: `git-*.nix` in `home/viluon/scripts/` exposed as git subcommands with completion

## Important Details

**SSH**: Passwordless auth with GitHub API keys (fixed hash), configured in `modules/system/networking`.

**Virtualization** (nixboerse): libvirtd with DNS routing hooks, Docker+minikube/kind firewall rules.

**Hardware**: NVIDIA (nixboerse), Intel graphics (nixboerse), AMD optimizations (nixluon via nixos-hardware).

**Packages**: Browser extensions auto-installed, `linux-entra-sso` with native messaging, overlays in flake.nix:82-86.

**DevShell**: `treefmt`, `just`, `nvd`. Enter with `nix develop` or `direnv`.

## Patterns & Pitfalls

**Host-specific**: Use `hostname` arg in modules/home configs.

**Unstable packages**: `unstable-pkgs` in modules, `inputs.nixpkgs-unstable.legacyPackages.${system}` in home.

**VM networking**: Use `forwardPorts`, not manual netdev.

**Kernel options**: Use `extraStructuredConfig` with `lib.kernel.yes`.

**Service hooks**: libvirtd hooks need `restartTriggers`.
