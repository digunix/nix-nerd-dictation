{ lib, stdenv, fetchFromGitHub, python3, python3Packages, fetchPypi, autoPatchelfHook, gcc-unwrapped, fetchurl, unzip, makeWrapper, pulseaudio, sox, pipewire, xdotool, ydotool, wtype, dotool }:

let
  # English VOSK model (US)
  vosk-model-en = stdenv.mkDerivation rec {
    pname = "vosk-model-small-en-us";
    version = "0.15";

    src = fetchurl {
      url = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip";
      sha256 = "sha256-MPJiQsTrRJ+UjkLLMC3XpobLKaNCOoNn+Z/0F4CUJJg=";
    };

    nativeBuildInputs = [ unzip ];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      mkdir -p $out/share/vosk-models
      cp -r vosk-model-small-en-us-0.15 $out/share/vosk-models/
    '';

    meta = with lib; {
      description = "Small US English VOSK speech recognition model";
      homepage = "https://alphacephei.com/vosk/";
      license = licenses.asl20;
    };
  };

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
    vosk-model-en
  ];

  installPhase =
    let
      wrapperScript = ''
        #!${stdenv.shell}

        # Add audio and input tools to PATH
        export PATH="${lib.makeBinPath [ pulseaudio sox pipewire xdotool ydotool wtype dotool ]}:$PATH"

        # Check if command needs model and input tool defaults
        needs_model=false
        model_specified=false
        input_tool_specified=false

        for arg in "$@"; do
            if [[ "$arg" == "begin" ]]; then
                needs_model=true
            fi
            if [[ "$arg" == --vosk-model-dir* ]]; then
                model_specified=true
            fi
            if [[ "$arg" == --simulate-input-tool* ]]; then
                input_tool_specified=true
            fi
        done

        # Add model path if command needs it and not already specified
        if [ "$needs_model" = true ] && [ "$model_specified" = false ]; then
            set -- "$@" --vosk-model-dir="${vosk-model-en}/share/vosk-models/vosk-model-small-en-us-0.15"
        fi

        # Setup default English configuration if it doesn't exist
        if [ "$needs_model" = true ]; then
            config_dir="$HOME/.config/nerd-dictation"
            config_file="$config_dir/nerd-dictation.py"

            if [ ! -f "$config_file" ]; then
                mkdir -p "$config_dir"
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
      to text input in various applications. This package includes VOSK and
      a US English language model (vosk-model-small-en-us-0.15).
    '';
    homepage = "https://github.com/ideasman42/nerd-dictation";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "nerd-dictation";
  };
}
