{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nerd-dictation;

  voskModels = import ./vosk-models.nix {
    inherit lib;
    inherit (pkgs) stdenv fetchurl unzip;
  };

  nerd-dictation = pkgs.callPackage ./package.nix {
    defaultModel = cfg.defaultModel;
  };

  configFile = pkgs.writeText "nerd-dictation.py" cfg.configScript;

  # Build the list of model packages based on user selection
  selectedModelPackages = map (m: voskModels.packages.${m}) cfg.models;
in

{
  options.services.nerd-dictation = {
    enable = mkEnableOption "nerd-dictation speech-to-text service";

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

        Note: Larger models will be downloaded during system build.
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

    user = mkOption {
      type = types.str;
      default = "nerd-dictation";
      description = "User account under which nerd-dictation runs";
    };

    group = mkOption {
      type = types.str;
      default = "nerd-dictation";
      description = "Group under which nerd-dictation runs";
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
      '';
    };

    modelPath = mkOption {
      type = types.str;
      default = "";
      description = "Path to the VOSK language model. Leave empty to use the configured default model.";
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

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to make available to nerd-dictation";
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
  };

  config = mkIf cfg.enable {
    # Validate that defaultModel is in the models list
    assertions = [
      {
        assertion = builtins.elem cfg.defaultModel cfg.models;
        message = "services.nerd-dictation.defaultModel must be one of the models in services.nerd-dictation.models";
      }
    ];

    # Enable uinput for dotool/ydotool support
    hardware.uinput.enable = mkIf (cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc" || cfg.inputBackend == "ydotool") true;
    boot.kernelModules = mkIf (cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc" || cfg.inputBackend == "ydotool") [ "uinput" ];

    users.users.${cfg.user} = mkIf (cfg.user == "nerd-dictation") {
      group = cfg.group;
      isSystemUser = true;
      description = "nerd-dictation service user";
      home = "/var/lib/nerd-dictation";
      createHome = true;
      extraGroups = [ "audio" ]
        ++ optional (cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc" || cfg.inputBackend == "ydotool") "uinput"
        ++ optional (cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc" || cfg.inputBackend == "ydotool") "input";
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "nerd-dictation") { };

    # Install nerd-dictation, selected models, and backend tools
    environment.systemPackages = [ cfg.package ]
      ++ selectedModelPackages
      ++ cfg.extraPackages
      ++ (with pkgs; [
        (mkIf (cfg.audioBackend == "parec") pulseaudio)
        (mkIf (cfg.audioBackend == "sox") sox)
        (mkIf (cfg.audioBackend == "pw-cat") pipewire)
        (mkIf (cfg.inputBackend == "xdotool") xdotool)
        (mkIf (cfg.inputBackend == "ydotool") ydotool)
        (mkIf (cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc") dotool)
        (mkIf (cfg.inputBackend == "wtype") wtype)
      ]);

    systemd.services.nerd-dictation = {
      description = "nerd-dictation speech-to-text service";
      after = [ "sound.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "forking";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "/var/lib/nerd-dictation";
        ExecStart = "${cfg.package}/bin/nerd-dictation begin --simulate-input-tool=${lib.toUpper cfg.inputBackend}";
        ExecStop = "${cfg.package}/bin/nerd-dictation end";
        Restart = "on-failure";
        RestartSec = 5;

        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/nerd-dictation" ];

        # Allow access to uinput for dotool/ydotool
        DeviceAllow = mkIf (cfg.inputBackend == "dotool" || cfg.inputBackend == "dotoolc" || cfg.inputBackend == "ydotool") [ "/dev/uinput rw" ];
      };

      environment = optionalAttrs (cfg.modelPath != "") {
        NERD_DICTATION_MODEL = cfg.modelPath;
      };

      preStart = ''
        mkdir -p /var/lib/nerd-dictation/.config/nerd-dictation
        ${optionalString (cfg.configScript != "") ''
          cp ${configFile} /var/lib/nerd-dictation/.config/nerd-dictation/nerd-dictation.py
        ''}
      '';
    };
  };
}
