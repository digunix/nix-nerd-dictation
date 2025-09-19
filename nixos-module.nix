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
      type = types.enum [ "xdotool" "ydotool" "dotool" "wtype" ];
      default = "xdotool";
      description = "Input simulation backend to use";
    };

    modelPath = mkOption {
      type = types.str;
      default = "";
      description = "Path to the VOSK language model";
    };

    configScript = mkOption {
      type = types.lines;
      default = "";
      description = "Python configuration script content";
      example = ''
        # Custom nerd-dictation configuration
        import re
        
        def text_replace_function(text):
            text = text.replace("new line", "\n")
            text = text.replace("tab", "\t")
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
    users.users.${cfg.user} = mkIf (cfg.user == "nerd-dictation") {
      group = cfg.group;
      isSystemUser = true;
      description = "nerd-dictation service user";
      home = "/var/lib/nerd-dictation";
      createHome = true;
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "nerd-dictation") { };

    environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages;

    systemd.services.nerd-dictation = {
      description = "nerd-dictation speech-to-text service";
      after = [ "sound.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "forking";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "/var/lib/nerd-dictation";
        ExecStart = "${cfg.package}/bin/nerd-dictation begin";
        ExecStop = "${cfg.package}/bin/nerd-dictation end";
        Restart = "on-failure";
        RestartSec = 5;
        
        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/nerd-dictation" ];
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

    # Ensure required audio/input packages are available
    environment.systemPackages = with pkgs; [
      (mkIf (cfg.audioBackend == "parec") pulseaudio)
      (mkIf (cfg.audioBackend == "sox") sox)
      (mkIf (cfg.audioBackend == "pw-cat") pipewire)
      (mkIf (cfg.inputBackend == "xdotool") xdotool)
      (mkIf (cfg.inputBackend == "ydotool") ydotool)
      (mkIf (cfg.inputBackend == "dotool") dotool)
      (mkIf (cfg.inputBackend == "wtype") wtype)
    ];

    # Add user to audio group for microphone access
    users.users.${cfg.user}.extraGroups = [ "audio" ];
  };
}