{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nerd-dictation;

  nerd-dictation = pkgs.callPackage ./package.nix { };

  configFile = pkgs.writeText "nerd-dictation.py" cfg.configScript;
in

{
  options.services.nerd-dictation = {
    enable = mkEnableOption "nerd-dictation speech-to-text service";

    package = mkOption {
      type = types.package;
      default = nerd-dictation;
      description = "The nerd-dictation package to use";
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
      description = "Path to the VOSK language model. Leave empty to use bundled English model.";
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

    environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages ++ (with pkgs; [
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
