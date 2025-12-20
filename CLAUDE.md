# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Repository:** `github:digunix/nix-nerd-dictation`

This is a Nix flake that packages [nerd-dictation](https://github.com/ideasman42/nerd-dictation), an offline speech-to-text tool, with VOSK and a US English language model bundled. It provides both NixOS and Home Manager modules for easy integration.

**Target environment:** Linux with Wayland (especially COSMIC desktop) and PulseAudio/PipeWire.

## Common Commands

```bash
# Build the package
nix build

# Run directly
nix run

# Check flake validity
nix flake check

# Update flake inputs
nix flake update

# Prefetch a new source hash
nix-prefetch-url --unpack <url>
nix hash to-sri --type sha256 <hash>
```

## Architecture

The flake consists of four main Nix files:

- **flake.nix** - Entry point exposing packages, apps, and modules for all systems
- **package.nix** - Main derivation that:
  - Fetches nerd-dictation from upstream GitHub (rev `41f3727...`)
  - Builds VOSK 0.3.45 as a Python wheel with autoPatchelfHook
  - Downloads and bundles the English VOSK model (vosk-model-small-en-us-0.15)
  - Creates a wrapper script with auto-detection of:
    - COSMIC desktop → uses `dotool` (uinput-based)
    - Other Wayland → uses `wtype`
    - X11 → uses `xdotool`
- **nixos-module.nix** - System-level service at `services.nerd-dictation`
  - Automatically enables `hardware.uinput` when using dotool/ydotool
  - Adds user to `uinput` and `input` groups
- **home-manager-module.nix** - User-level configuration at `programs.nerd-dictation`
  - Emits warnings about uinput requirements
  - Supports i3/sway keybindings

## Key Design Decisions

1. **Bundled dependencies**: VOSK and the English model are packaged inline for zero-config setup
2. **COSMIC-first**: Default input backend is `dotool` which uses uinput kernel module, bypassing Wayland protocol restrictions that affect COSMIC
3. **Auto-detection**: The wrapper script detects COSMIC via `$XDG_CURRENT_DESKTOP` and `$COSMIC_SESSION` environment variables
4. **uinput integration**: NixOS module auto-configures `hardware.uinput.enable` and required groups
5. **English configuration**: `default-config.py` provides English punctuation, symbols, and programming shortcuts

## Input Backend Selection

| Backend | Mechanism | COSMIC Support |
|---------|-----------|----------------|
| `dotool` | uinput kernel module | Yes (recommended) |
| `dotoolc` | uinput via daemon | Yes |
| `wtype` | wlr-virtual-keyboard protocol | No (blocked by security) |
| `ydotool` | uinput kernel module | Yes |
| `xdotool` | X11 protocol | No (X11 only) |

## Module Options

Both modules share similar options:
- `inputBackend`: dotool (default), dotoolc, wtype, ydotool, or xdotool
- `audioBackend`: parec (default), sox, or pw-cat
- `modelPath`: Override the bundled English model path
- `configScript`: Custom Python text processing function
- `timeout`/`idleTime`: Speech recognition timing parameters

Home Manager module additionally provides:
- `keyBindings`: Configure hotkeys for i3/sway
- `enableSystemdService`: User-level systemd service
- Shell aliases: `nd-begin`, `nd-end`, `nd-suspend`

## Updating Dependencies

To update nerd-dictation:
```bash
# Get latest commit from https://github.com/ideasman42/nerd-dictation
nix-prefetch-url --unpack https://github.com/ideasman42/nerd-dictation/archive/<commit>.tar.gz
```

To update VOSK model:
```bash
# Check https://alphacephei.com/vosk/models for new versions
nix-prefetch-url https://alphacephei.com/vosk/models/vosk-model-small-en-us-<version>.zip
```
