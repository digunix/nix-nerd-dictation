# VOSK English speech recognition models
# See https://alphacephei.com/vosk/models for more information

{ lib, stdenv, fetchurl, unzip }:

let
  # Model definitions with metadata
  modelDefs = {
    "small-en-us" = {
      name = "vosk-model-small-en-us-0.15";
      version = "0.15";
      url = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip";
      hash = "sha256-MPJiQsTrRJ+UjkLLMC3XpobLKaNCOoNn+Z/0F4CUJJg=";
      size = "40MB";
      description = "Lightweight model for Android/Raspberry Pi - good for basic use";
    };

    "en-us-0.22" = {
      name = "vosk-model-en-us-0.22";
      version = "0.22";
      url = "https://alphacephei.com/vosk/models/vosk-model-en-us-0.22.zip";
      hash = "sha256-kakOhA7hEtDM6WY3oAnb8xKZil9WTA3xePpLIxr2+yM=";
      size = "1.8GB";
      description = "Large accurate model for servers/desktops - best general accuracy";
    };

    "en-us-0.22-lgraph" = {
      name = "vosk-model-en-us-0.22-lgraph";
      version = "0.22";
      url = "https://alphacephei.com/vosk/models/vosk-model-en-us-0.22-lgraph.zip";
      hash = "sha256-2YOLSqqCp1xKF/WsowDqyhKaqrKny/lRuvu1AOucQzQ=";
      size = "128MB";
      description = "Dynamic graph model - good balance of size and accuracy";
    };

    "en-us-0.42-gigaspeech" = {
      name = "vosk-model-en-us-0.42-gigaspeech";
      version = "0.42";
      url = "https://alphacephei.com/vosk/models/vosk-model-en-us-0.42-gigaspeech.zip";
      hash = "sha256-75XKJKhO4e/2iNBkWmRJIjaaWtC2VJyOM1XuUJUcRDs=";
      size = "2.3GB";
      description = "Trained on Gigaspeech - optimized for podcasts/conversations";
    };
  };

  # Function to build a model package
  mkModel = key: def: stdenv.mkDerivation {
    pname = "vosk-model-${key}";
    version = def.version;

    src = fetchurl {
      inherit (def) url hash;
    };

    nativeBuildInputs = [ unzip ];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      mkdir -p $out/share/vosk-models

      # Move the model directory
      mv ${def.name} $out/share/vosk-models/${key}

      # Create metadata file for runtime discovery
      cat > $out/share/vosk-models/${key}.json <<EOF
      {
        "key": "${key}",
        "name": "${def.name}",
        "version": "${def.version}",
        "size": "${def.size}",
        "description": "${def.description}"
      }
      EOF
    '';

    meta = with lib; {
      description = "VOSK model: ${def.description}";
      homepage = "https://alphacephei.com/vosk/models";
      license = licenses.asl20;
      platforms = platforms.all;
    };
  };

in {
  # Export model definitions for use in modules
  definitions = modelDefs;

  # List of available model keys
  availableModels = builtins.attrNames modelDefs;

  # Pre-built model packages
  packages = lib.mapAttrs mkModel modelDefs;

  # Helper to get model package by key
  getModel = key: mkModel key modelDefs.${key};
}
