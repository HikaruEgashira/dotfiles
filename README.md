### dotfiles

Prerequisites
- [Nix](https://nixos.org/)

Installation
```bash
gh repo clone HikaruEgashira/dotfiles ~/dotfiles
nix run ~/dotfiles#homeConfigurations.hikae.activationPackage
```

## Managed configs

- **home-manager** — shell, git, packages, fonts via Nix flakes
