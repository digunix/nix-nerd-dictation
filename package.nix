{ lib, stdenv, fetchFromGitHub, python3, python3Packages, fetchPypi, autoPatchelfHook, gcc-unwrapped, fetchurl, unzip, makeWrapper, pulseaudio, sox, pipewire, xdotool, ydotool, wtype, dotool, jq
, defaultModel ? "small-en-us"
}:

let
  vosk = python3Packages.buildPythonPackage rec {
    pname = "vosk";
    version = "0.3.45";
    format = "wheel";

    src = fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      abi = "none";
      platform = "manylinux_2_12_x86_64.manylinux2010_x86_64";
      sha256 = "sha256-JeAlCTxDmdcnj1Q1aO2MxUYKw6S/SMI2c6zh4l0mYZ8=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];

    buildInputs = [ gcc-unwrapped.lib ];

    propagatedBuildInputs = with python3Packages; [
      cffi
      requests
      tqdm
      srt
    ];

    doCheck = false;

    meta = with lib; {
      description = "Offline speech recognition API";
      homepage = "https://alphacephei.com/vosk/";
      license = licenses.asl20;
    };
  };

  pythonWithVosk = python3.withPackages (ps: with ps; [ vosk setuptools ]);
in

stdenv.mkDerivation rec {
  pname = "nerd-dictation";
  version = "unstable-2025-10-10";

  src = fetchFromGitHub {
    owner = "ideasman42";
    repo = "nerd-dictation";
    rev = "41f372789c640e01bb6650339a78312661530843";
    sha256 = "sha256-xjaHrlJvk8bNvWp1VE4EAHi2VJlAutBxUgWB++3Qo+s=";
  };

  nativeBuildInputs = [
    pythonWithVosk
    makeWrapper
  ];

  propagatedBuildInputs = [
    pythonWithVosk
    jq
  ];

  installPhase =
    let
      wrapperScript = ''
        #!${stdenv.shell}

        # Add audio and input tools to PATH
        export PATH="${lib.makeBinPath [ pulseaudio sox pipewire xdotool ydotool wtype dotool jq ]}:$PATH"

        CONFIG_DIR="$HOME/.config/nerd-dictation"
        ACTIVE_MODEL_FILE="$CONFIG_DIR/active-model"

        # Default model if not configured
        DEFAULT_MODEL="${defaultModel}"

        # Get the active model from config or use default
        get_active_model() {
            if [ -f "$ACTIVE_MODEL_FILE" ]; then
                cat "$ACTIVE_MODEL_FILE"
            else
                echo "$DEFAULT_MODEL"
            fi
        }

        # Find models directory - check common paths
        find_models_path() {
            if [ -n "$VOSK_MODELS_PATH" ] && [ -d "$VOSK_MODELS_PATH" ]; then
                echo "$VOSK_MODELS_PATH"
            elif [ -d "/run/current-system/sw/share/vosk-models" ]; then
                echo "/run/current-system/sw/share/vosk-models"
            elif [ -d "$HOME/.nix-profile/share/vosk-models" ]; then
                echo "$HOME/.nix-profile/share/vosk-models"
            elif [ -d "/nix/var/nix/profiles/default/share/vosk-models" ]; then
                echo "/nix/var/nix/profiles/default/share/vosk-models"
            else
                echo ""
            fi
        }

        # List available models
        list_models() {
            local models_path=$(find_models_path)
            if [ -z "$models_path" ]; then
                echo "No models found. Install models via your NixOS/Home Manager configuration."
                echo ""
                echo "Available models:"
                echo "  small-en-us      (40MB)  - Lightweight, good for basic use"
                echo "  en-us-0.22       (1.8GB) - High accuracy for desktops/servers"
                echo "  en-us-0.22-lgraph (128MB) - Good balance of size and accuracy"
                echo "  en-us-0.42-gigaspeech (2.3GB) - Optimized for podcasts"
                exit 1
            fi

            local active=$(get_active_model)
            echo "Installed models (in $models_path):"
            echo ""

            for json_file in "$models_path"/*.json; do
                if [ -f "$json_file" ]; then
                    local key=$(jq -r '.key' "$json_file" 2>/dev/null)
                    local size=$(jq -r '.size' "$json_file" 2>/dev/null)
                    local desc=$(jq -r '.description' "$json_file" 2>/dev/null)

                    if [ "$key" = "$active" ]; then
                        echo "* $key ($size) [active]"
                    else
                        echo "  $key ($size)"
                    fi
                    echo "    $desc"
                    echo ""
                fi
            done
        }

        # Show active model
        show_active() {
            local active=$(get_active_model)
            local models_path=$(find_models_path)

            echo "Active model: $active"

            if [ -n "$models_path" ] && [ -f "$models_path/$active.json" ]; then
                local desc=$(jq -r '.description' "$models_path/$active.json" 2>/dev/null)
                local size=$(jq -r '.size' "$models_path/$active.json" 2>/dev/null)
                echo "Size: $size"
                echo "Description: $desc"
            fi
        }

        # Set active model
        set_model() {
            local model="$1"
            local models_path=$(find_models_path)

            if [ -z "$model" ]; then
                echo "Usage: nerd-dictation models set <model-name>"
                echo ""
                echo "Run 'nerd-dictation models list' to see available models."
                exit 1
            fi

            # Check if model exists
            if [ -n "$models_path" ] && [ -d "$models_path/$model" ]; then
                mkdir -p "$CONFIG_DIR"
                echo "$model" > "$ACTIVE_MODEL_FILE"
                echo "Active model set to: $model"
                echo ""
                echo "Note: If dictation is currently running, stop and restart it to use the new model."
            else
                echo "Error: Model '$model' not found."
                echo ""
                echo "Run 'nerd-dictation models list' to see available models."
                exit 1
            fi
        }

        # Get model path for the active or specified model
        get_model_path() {
            local model="$1"
            local models_path=$(find_models_path)

            if [ -z "$model" ]; then
                model=$(get_active_model)
            fi

            if [ -n "$models_path" ] && [ -d "$models_path/$model" ]; then
                echo "$models_path/$model"
            else
                echo ""
            fi
        }

        # Handle model subcommand
        if [ "$1" = "models" ] || [ "$1" = "model" ]; then
            case "$2" in
                ""|list)
                    list_models
                    exit 0
                    ;;
                active)
                    show_active
                    exit 0
                    ;;
                set)
                    set_model "$3"
                    exit 0
                    ;;
                *)
                    echo "Usage: nerd-dictation models [list|active|set <model>]"
                    echo ""
                    echo "Commands:"
                    echo "  list        List installed models"
                    echo "  active      Show the currently active model"
                    echo "  set <name>  Set the active model"
                    exit 1
                    ;;
            esac
        fi

        # Check if command needs model and input tool defaults
        needs_model=false
        model_specified=false
        input_tool_specified=false
        specified_model=""

        for arg in "$@"; do
            if [[ "$arg" == "begin" ]]; then
                needs_model=true
            fi
            if [[ "$arg" == --vosk-model-dir* ]]; then
                model_specified=true
            fi
            if [[ "$arg" == --model=* ]]; then
                specified_model="''${arg#--model=}"
            fi
            if [[ "$arg" == --simulate-input-tool* ]]; then
                input_tool_specified=true
            fi
        done

        # Filter out --model= argument (we handle it ourselves)
        args=()
        for arg in "$@"; do
            if [[ "$arg" != --model=* ]]; then
                args+=("$arg")
            fi
        done
        set -- "''${args[@]}"

        # Add model path if command needs it and not already specified
        if [ "$needs_model" = true ] && [ "$model_specified" = false ]; then
            if [ -n "$specified_model" ]; then
                model_path=$(get_model_path "$specified_model")
            else
                model_path=$(get_model_path)
            fi

            if [ -n "$model_path" ]; then
                set -- "$@" --vosk-model-dir="$model_path"
            else
                echo "Error: No model available. Install a model via your NixOS/Home Manager configuration."
                echo ""
                echo "Run 'nerd-dictation models list' for more information."
                exit 1
            fi
        fi

        # Setup default English configuration if it doesn't exist
        if [ "$needs_model" = true ]; then
            config_file="$CONFIG_DIR/nerd-dictation.py"

            if [ ! -f "$config_file" ]; then
                mkdir -p "$CONFIG_DIR"
                cp @out@/share/nerd-dictation/default-config.py "$config_file"
                echo "English configuration installed to $config_file"
            fi
        fi

        # Auto-detect and set input tool based on environment
        if [ "$needs_model" = true ] && [ "$input_tool_specified" = false ]; then
            if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
                # Wayland detected - check for COSMIC desktop
                if [ "$XDG_CURRENT_DESKTOP" = "COSMIC" ] || [ -n "$COSMIC_SESSION" ]; then
                    # COSMIC desktop - use DOTOOL (works via uinput, bypasses Wayland restrictions)
                    set -- "$@" --simulate-input-tool=DOTOOL
                else
                    # Other Wayland compositors (Sway, GNOME, etc.) - try WTYPE first
                    set -- "$@" --simulate-input-tool=WTYPE
                fi
            else
                # X11 or fallback - use XDOTOOL
                set -- "$@" --simulate-input-tool=XDOTOOL
            fi
        fi

        exec ${pythonWithVosk}/bin/python3 @out@/share/nerd-dictation/nerd-dictation "$@"
      '';
    in
    ''
      runHook preInstall

      mkdir -p $out/bin
      mkdir -p $out/share/nerd-dictation

      # Copy all source files
      cp -r . $out/share/nerd-dictation/

      # Copy default English configuration
      cp ${./default-config.py} $out/share/nerd-dictation/default-config.py

      # Create wrapper script with model path and dependencies
      cat > $out/bin/nerd-dictation << 'WRAPPER_EOF'
      ${wrapperScript}
      WRAPPER_EOF

      # Substitute the output path
      substituteInPlace $out/bin/nerd-dictation --replace-fail "@out@" "$out"

      chmod +x $out/bin/nerd-dictation

      runHook postInstall
    '';

  meta = with lib; {
    description = "Simple, hackable offline speech to text";
    longDescription = ''
      nerd-dictation is a tool for offline speech-to-text. It uses VOSK for
      speech recognition and provides a simple interface for converting speech
      to text input in various applications. This package includes VOSK.
      Install VOSK models separately via the models option.
    '';
    homepage = "https://github.com/ideasman42/nerd-dictation";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "nerd-dictation";
  };
}
