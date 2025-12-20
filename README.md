# nerd-dictation Nix Flake

A Nix flake for [nerd-dictation](https://github.com/ideasman42/nerd-dictation), an offline speech-to-text tool.

## Credits

- **[nerd-dictation](https://github.com/ideasman42/nerd-dictation)** by Campbell Barton ([@ideasman42](https://github.com/ideasman42)) - The upstream speech-to-text tool this flake packages
- **[Original Nix flake](https://github.com/fclaeys/nix-nerd-dictation)** by Fabrice Claeys ([@fclaeys](https://github.com/fclaeys)) - Created the initial French version of this Nix flake with NixOS and Home Manager modules

## Features

- VOSK 0.3.45 included
- US English model `vosk-model-small-en-us-0.15` bundled
- **Automatic Wayland/X11 detection** for text input
- **COSMIC desktop support** via dotool
- **COSMIC panel applet** with status indicator and controls
- **English configuration** with punctuation and symbols
- Ready to use with no additional setup

## Quick Start

```bash
nix run github:digunix/nix-nerd-dictation
```

## NixOS Configuration

### Flake Setup

Add the flake to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nerd-dictation.url = "github:digunix/nix-nerd-dictation";
  };

  outputs = { self, nixpkgs, nerd-dictation, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nerd-dictation.nixosModules.default
      ];
    };
  };
}
```

### Complete NixOS Configuration Example

Add to your `configuration.nix`:

```nix
{ config, pkgs, ... }:

{
  # Enable nerd-dictation service
  services.nerd-dictation = {
    enable = true;
    inputBackend = "dotool";  # Recommended for Wayland/COSMIC
    audioBackend = "parec";   # Works with PulseAudio/PipeWire
  };

  # Required for dotool to work (automatically enabled by the module)
  hardware.uinput.enable = true;

  # Add your user to required groups
  users.users.youruser = {
    extraGroups = [ "audio" "input" ];
  };

  # If using PipeWire (recommended)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
```

### Standalone Package (without service)

If you just want the package without the systemd service:

```nix
{ config, pkgs, nerd-dictation, ... }:

{
  environment.systemPackages = [
    nerd-dictation.packages.${pkgs.system}.default
  ];

  # Still needed for dotool
  hardware.uinput.enable = true;
  users.users.youruser.extraGroups = [ "audio" "input" ];
}
```

## Home Manager Configuration

### With Flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nerd-dictation.url = "github:digunix/nix-nerd-dictation";
  };

  outputs = { self, nixpkgs, home-manager, nerd-dictation, ... }: {
    homeConfigurations.youruser = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        nerd-dictation.homeModules.default
        {
          programs.nerd-dictation = {
            enable = true;
            inputBackend = "dotool";
            enableSystemdService = true;

            # Key bindings for i3/sway (optional)
            keyBindings = {
              "ctrl+alt+d" = "nerd-dictation begin";
              "ctrl+alt+shift+d" = "nerd-dictation end";
            };
          };
        }
      ];
    };
  };
}
```

### NixOS Requirements for Home Manager

Home Manager users still need NixOS-level configuration for uinput:

```nix
# In your NixOS configuration.nix
hardware.uinput.enable = true;
users.users.youruser.extraGroups = [ "input" ];
```

**Important:** Do NOT enable both the NixOS service (`services.nerd-dictation.enable`) and the Home Manager service (`programs.nerd-dictation.enableSystemdService`) at the same time. This creates two competing services that will conflict.

### Service Behavior

The systemd services (both NixOS and Home Manager) are configured to automatically restart on failure. This means if you stop nerd-dictation manually while the service is enabled, it will restart automatically. To fully stop dictation:

1. Stop the service: `systemctl --user stop nerd-dictation` (or without `--user` for NixOS service)
2. Disable if needed: `systemctl --user disable nerd-dictation`

Or use `nerd-dictation end` which gracefully stops the current session without triggering a restart.

## COSMIC Desktop Setup

For COSMIC desktop, the package automatically uses `dotool` which works via the uinput kernel module.

### COSMIC Panel Applet

A panel applet is included that shows dictation status and provides controls:

| Icon | Status |
|------|--------|
| Red microphone | Stopped |
| Green microphone | Active |
| Yellow microphone | Suspended |

Click the icon to open a popup with Start/Stop/Suspend/Resume controls.

### Recommended Configuration for Applet Users

If you're using the COSMIC applet for manual control, you likely don't want automatic systemd services running. Here's the recommended setup:

```nix
# configuration.nix
{ nerd-dictation, pkgs, ... }:

{
  # Import the NixOS module for system dependencies only
  imports = [ nerd-dictation.nixosModules.default ];

  # DON'T enable the service - we want manual control via applet
  services.nerd-dictation.enable = false;

  # Install the applet and nerd-dictation command
  environment.systemPackages = [
    nerd-dictation.packages.${pkgs.system}.default
    nerd-dictation.packages.${pkgs.system}.cosmic-applet
  ];

  # Required system configuration for dotool
  hardware.uinput.enable = true;
  users.users.youruser.extraGroups = [ "audio" "input" ];

  # COSMIC desktop
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # PipeWire for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
```

If using Home Manager alongside the applet, set `enableSystemdService = false`:

```nix
programs.nerd-dictation = {
  enable = true;
  enableSystemdService = false;  # Manual control via applet
};
```

Then add **Nerd Dictation** to your COSMIC panel via **Settings > Desktop > Panel > Applets**.

### Run Without Installing

```bash
nix run github:digunix/nix-nerd-dictation#cosmic-applet
```

### Keyboard Shortcuts

Configure in **COSMIC Settings > Keyboard > Keyboard Shortcuts**:

| Action | Command |
|--------|---------|
| Start dictation | `nerd-dictation begin` |
| Stop dictation | `nerd-dictation end` |
| Toggle pause | `nerd-dictation suspend` |

## Configuration Reference

### Input Backends

| Backend | Environment | Notes |
|---------|-------------|-------|
| `dotool` | Wayland/X11/COSMIC | **Recommended.** Uses uinput, works everywhere |
| `dotoolc` | Wayland/X11/COSMIC | Same as dotool, uses daemon for better performance |
| `wtype` | Wayland (wlroots) | Works on Sway, may not work on COSMIC |
| `ydotool` | Wayland/X11 | Alternative to dotool, requires daemon |
| `xdotool` | X11 only | Classic X11 tool |

### Audio Backends

| Backend | Description |
|---------|-------------|
| `parec` | PulseAudio/PipeWire (default) |
| `sox` | SoX audio tools |
| `pw-cat` | PipeWire native |

### Module Options

| Option | Default | Description |
|--------|---------|-------------|
| `inputBackend` | `dotool` | Input simulation tool |
| `audioBackend` | `parec` | Audio recording tool |
| `modelPath` | (bundled) | Custom VOSK model path |
| `configScript` | (bundled) | Custom Python config |
| `timeout` | 1000 | Recognition timeout (ms) |
| `idleTime` | 500 | Idle time before stop (ms) |
| `convertNumbers` | false | Convert words to digits |

## Voice Commands

The bundled English configuration supports these spoken commands:

### Punctuation
| Say | Output |
|-----|--------|
| "comma" | `,` |
| "period" / "full stop" | `.` |
| "question mark" | `?` |
| "exclamation mark" | `!` |
| "colon" | `:` |
| "semicolon" | `;` |
| "ellipsis" | `...` |

### Navigation
| Say | Output |
|-----|--------|
| "new line" | newline |
| "new paragraph" | double newline |
| "tab" | tab character |

### Brackets & Quotes
| Say | Output |
|-----|--------|
| "open paren" / "close paren" | `(` `)` |
| "open bracket" / "close bracket" | `[` `]` |
| "open brace" / "close brace" | `{` `}` |
| "open quote" / "close quote" | `"` |

### Symbols
| Say | Output |
|-----|--------|
| "at sign" | `@` |
| "hash" / "hashtag" | `#` |
| "dollar" | `$` |
| "percent" | `%` |
| "ampersand" | `&` |
| "asterisk" / "star" | `*` |
| "plus" | `+` |
| "equals" | `=` |
| "slash" | `/` |
| "backslash" | `\` |

### Programming
| Say | Output |
|-----|--------|
| "arrow" | `->` |
| "fat arrow" | `=>` |
| "double equals" | `==` |
| "triple equals" | `===` |
| "not equals" | `!=` |
| "plus plus" | `++` |
| "minus minus" | `--` |

## Shell Aliases

The Home Manager module adds these aliases (bash/zsh/fish):

- `nd-begin` - Start dictation
- `nd-end` - Stop dictation
- `nd-suspend` - Toggle pause

## Troubleshooting

### dotool not working

1. Verify uinput is enabled:
   ```bash
   ls -la /dev/uinput
   ```

2. Check group membership:
   ```bash
   groups  # Should include 'input'
   ```

3. If recently changed, log out and back in or reboot

4. Check uinput module is loaded:
   ```bash
   lsmod | grep uinput
   ```

### No audio input

1. List available sources:
   ```bash
   pactl list sources short
   ```

2. Test recording:
   ```bash
   parec --channels=1 --rate=16000 test.raw
   ```

3. Check PipeWire/PulseAudio is running:
   ```bash
   systemctl --user status pipewire pipewire-pulse
   ```

### COSMIC: text not appearing

COSMIC has security measures against input spoofing. Ensure:

1. Using `dotool` (not `wtype`)
2. uinput is properly configured
3. User is in `input` group
4. Logged out and back in after group changes

### Model not loading

Check the model path:
```bash
nerd-dictation begin --vosk-model-dir=/path/to/model
```

### Service won't stay stopped

If nerd-dictation keeps restarting after you stop it, a systemd service is configured to auto-restart. Either:

1. **Disable the service:**
   ```bash
   # For Home Manager service
   systemctl --user disable --now nerd-dictation

   # For NixOS service
   sudo systemctl disable --now nerd-dictation
   ```

2. **Or update your config** to disable the service if using the COSMIC applet for manual control:
   ```nix
   # NixOS
   services.nerd-dictation.enable = false;

   # Home Manager
   programs.nerd-dictation.enableSystemdService = false;
   ```

See [Recommended Configuration for Applet Users](#recommended-configuration-for-applet-users) for the full setup.

## Custom Configuration

Create `~/.config/nerd-dictation/nerd-dictation.py` to customize text processing:

```python
def nerd_dictation_process(text):
    # Add custom replacements
    text = text.replace(" my email", "user@example.com")
    text = text.replace(" my phone", "555-1234")

    # Call default processing (optional)
    # from default_config import nerd_dictation_process as default
    # text = default(text)

    return text
```

