{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.nerd-dictation;

  voskModels = import ./vosk-models.nix {
    inherit lib;
    inherit (pkgs) stdenv fetchurl unzip;
  };

  nerd-dictation = pkgs.callPackage ./package.nix {
    defaultModel = cfg.defaultModel;
  };

  configFile = pkgs.writeText "nerd-dictation.py" cfg.configScript;

  # Check if using uinput-based backend
  usesUinput = cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc" || cfg.inputBackend == "ydotool";

  # Build the list of model packages based on user selection
  selectedModelPackages = map (m: voskModels.packages.${m}) cfg.models;
in

{
  options.programs.nerd-dictation = {
    enable = mkEnableOption "nerd-dictation speech-to-text";

    package = mkOption {
      type = types.package;
      default = nerd-dictation;
      description = "The nerd-dictation package to use";
    };

    models = mkOption {
      type = types.listOf (types.enum voskModels.availableModels);
      default = [ "small-en-us" ];
      example = [ "small-en-us" "en-us-0.22" ];
      description = ''
        List of VOSK models to install. Available models:
        - small-en-us (40MB) - Lightweight model for basic use
        - en-us-0.22 (1.8GB) - High accuracy model for desktops/servers
        - en-us-0.22-lgraph (128MB) - Good balance of size and accuracy
        - en-us-0.42-gigaspeech (2.3GB) - Optimized for podcasts/conversations

        Note: Larger models will be downloaded during build.
      '';
    };

    defaultModel = mkOption {
      type = types.enum voskModels.availableModels;
      default = "small-en-us";
      description = ''
        Default model to use when none is explicitly configured.
        Must be one of the models listed in the 'models' option.
      '';
    };

    audioBackend = mkOption {
      type = types.enum [ "parec" "sox" "pw-cat" ];
      default = "parec";
      description = "Audio recording backend to use";
    };

    inputBackend = mkOption {
      type = types.enum [ "xdotool" "ydotool" "dotool" "dotoolc" "wtype" ];
      default = "dotool";
      description = ''
        Input simulation backend to use.
        - dotool: Recommended for Wayland/COSMIC, uses uinput kernel module
        - dotoolc: Same as dotool but uses the dotoold daemon
        - wtype: Works on wlroots-based compositors (Sway, etc.)
        - ydotool: Alternative uinput-based tool, requires daemon
        - xdotool: X11 only

        Note: dotool/dotoolc/ydotool require uinput kernel module and user in 'input' group.
        Add to your NixOS config:
          hardware.uinput.enable = true;
          users.users.youruser.extraGroups = [ "input" ];
      '';
    };

    modelPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to the VOSK language model. Leave null to use the configured default model.";
    };

    configScript = mkOption {
      type = types.lines;
      default = "";
      description = "Python configuration script content";
      example = ''
        # Custom nerd-dictation configuration
        import re

        def nerd_dictation_process(text):
            text = text.replace(" new line", "\n")
            text = text.replace(" tab", "\t")
            return text
      '';
    };

    timeout = mkOption {
      type = types.int;
      default = 1000;
      description = "Timeout in milliseconds for speech recognition";
    };

    idleTime = mkOption {
      type = types.int;
      default = 500;
      description = "Idle time in milliseconds before stopping recording";
    };

    convertNumbers = mkOption {
      type = types.bool;
      default = false;
      description = "Convert number words to digits";
    };

    keyBindings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Key bindings for nerd-dictation commands.
        These are applied to i3/sway if enabled.
        For COSMIC desktop, configure shortcuts in Settings > Keyboard > Keyboard Shortcuts.
      '';
      example = {
        "ctrl+alt+d" = "nerd-dictation begin";
        "ctrl+alt+shift+d" = "nerd-dictation end";
        "ctrl+alt+s" = "nerd-dictation suspend";
      };
    };

    enableSystemdService = mkOption {
      type = types.bool;
      default = false;
      description = "Enable systemd user service for nerd-dictation";
    };
  };

  config = mkIf cfg.enable {
    # Validate that defaultModel is in the models list
    assertions = [
      {
        assertion = builtins.elem cfg.defaultModel cfg.models;
        message = "programs.nerd-dictation.defaultModel must be one of the models in programs.nerd-dictation.models";
      }
    ];

    home.packages = [ cfg.package ]
      ++ selectedModelPackages
      ++ (with pkgs; [
        # Audio backends
        (mkIf (cfg.audioBackend == "parec") pulseaudio)
        (mkIf (cfg.audioBackend == "sox") sox)
        (mkIf (cfg.audioBackend == "pw-cat") pipewire)

        # Input backends
        (mkIf (cfg.inputBackend == "xdotool") xdotool)
        (mkIf (cfg.inputBackend == "ydotool") ydotool)
        (mkIf (cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc") dotool)
        (mkIf (cfg.inputBackend == "wtype") wtype)
      ]);

    # Create config directory and file
    xdg.configFile."nerd-dictation/nerd-dictation.py" = mkIf (cfg.configScript != "") {
      text = cfg.configScript;
    };

    # Environment variables
    home.sessionVariables = optionalAttrs (cfg.modelPath != null) {
      NERD_DICTATION_MODEL = cfg.modelPath;
    };

    # Systemd user service
    systemd.user.services.nerd-dictation = mkIf cfg.enableSystemdService {
      Unit = {
        Description = "nerd-dictation speech-to-text service";
        After = [ "graphical-session.target" ];
      };

      Service = {
        Type = "forking";
        ExecStart = "${cfg.package}/bin/nerd-dictation begin --simulate-input-tool=${lib.toUpper cfg.inputBackend} --timeout=${toString cfg.timeout} --idle-time=${toString cfg.idleTime}${optionalString cfg.convertNumbers " --numbers-as-digits"}";
        ExecStop = "${cfg.package}/bin/nerd-dictation end";
        ExecReload = "${cfg.package}/bin/nerd-dictation suspend";
        Restart = "on-failure";
        RestartSec = 5;

        Environment = optional (cfg.modelPath != null) "NERD_DICTATION_MODEL=${cfg.modelPath}";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Create wrapper scripts for common commands
    home.file.".local/bin/nerd-dictation-begin" = {
      text = ''
        #!/bin/sh
        ${cfg.package}/bin/nerd-dictation begin --simulate-input-tool=${lib.toUpper cfg.inputBackend} --timeout=${toString cfg.timeout} --idle-time=${toString cfg.idleTime}${optionalString cfg.convertNumbers " --numbers-as-digits"}
      '';
      executable = true;
    };

    home.file.".local/bin/nerd-dictation-end" = {
      text = ''
        #!/bin/sh
        ${cfg.package}/bin/nerd-dictation end
      '';
      executable = true;
    };

    home.file.".local/bin/nerd-dictation-suspend" = {
      text = ''
        #!/bin/sh
        ${cfg.package}/bin/nerd-dictation suspend
      '';
      executable = true;
    };

    # Shell aliases for convenience
    programs.bash.shellAliases = mkIf config.programs.bash.enable {
      nd-begin = "nerd-dictation-begin";
      nd-end = "nerd-dictation-end";
      nd-suspend = "nerd-dictation-suspend";
    };

    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      nd-begin = "nerd-dictation-begin";
      nd-end = "nerd-dictation-end";
      nd-suspend = "nerd-dictation-suspend";
    };

    programs.fish.shellAliases = mkIf config.programs.fish.enable {
      nd-begin = "nerd-dictation-begin";
      nd-end = "nerd-dictation-end";
      nd-suspend = "nerd-dictation-suspend";
    };

    # Key bindings for i3/sway (if enabled)
    wayland.windowManager.sway.config.keybindings = mkIf (config.wayland.windowManager.sway.enable && cfg.keyBindings != {})
      (mapAttrs (key: cmd: "exec ${cmd}") cfg.keyBindings);

    xsession.windowManager.i3.config.keybindings = mkIf (config.xsession.windowManager.i3.enable && cfg.keyBindings != {})
      (mapAttrs (key: cmd: "exec ${cmd}") cfg.keyBindings);

    # Warning for uinput-based backends
    warnings = optional usesUinput ''
      nerd-dictation: You are using ${cfg.inputBackend} which requires uinput.
      Ensure your NixOS configuration includes:
        hardware.uinput.enable = true;
        users.users.${config.home.username}.extraGroups = [ "input" ];
    '';
  };
}
