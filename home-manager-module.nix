{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.nerd-dictation;
  
  nerd-dictation = pkgs.callPackage ./package.nix { };
  
  configFile = pkgs.writeText "nerd-dictation.py" cfg.configScript;
in

{
  options.programs.nerd-dictation = {
    enable = mkEnableOption "nerd-dictation speech-to-text";

    package = mkOption {
      type = types.package;
      default = nerd-dictation;
      description = "The nerd-dictation package to use";
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
      type = types.nullOr types.str;
      default = null;
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
      default = {
        "ctrl+alt+d" = "nerd-dictation begin";
        "ctrl+alt+shift+d" = "nerd-dictation end";
      };
      description = "Key bindings for nerd-dictation commands";
      example = {
        "super+d" = "nerd-dictation begin";
        "super+shift+d" = "nerd-dictation end";
        "super+ctrl+d" = "nerd-dictation suspend";
      };
    };

    enableSystemdService = mkOption {
      type = types.bool;
      default = false;
      description = "Enable systemd user service for nerd-dictation";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ] ++ (with pkgs; [
      # Audio backends
      (mkIf (cfg.audioBackend == "parec") pulseaudio)
      (mkIf (cfg.audioBackend == "sox") sox)
      (mkIf (cfg.audioBackend == "pw-cat") pipewire)
      
      # Input backends
      (mkIf (cfg.inputBackend == "xdotool") xdotool)
      (mkIf (cfg.inputBackend == "ydotool") ydotool)
      (mkIf (cfg.inputBackend == "dotool") dotool)
      (mkIf (cfg.inputBackend == "wtype") wtype)
      
      # VOSK is now included in the package
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
        ExecStart = "${cfg.package}/bin/nerd-dictation begin --timeout=${toString cfg.timeout} --idle-time=${toString cfg.idleTime}${optionalString cfg.convertNumbers " --numbers-as-digits"}";
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
        ${cfg.package}/bin/nerd-dictation begin --timeout=${toString cfg.timeout} --idle-time=${toString cfg.idleTime}${optionalString cfg.convertNumbers " --numbers-as-digits"}
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
  };
}