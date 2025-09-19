# nerd-dictation Nix Flake

Ce flake Nix fournit un package et des modules NixOS/Home Manager pour [nerd-dictation](https://github.com/ideasman42/nerd-dictation), un outil de dictée vocale hors ligne.

## ✅ Installation complètement automatisée

VOSK et le modèle français sont maintenant inclus automatiquement dans le package ! 

- ✅ VOSK 0.3.45 inclus
- ✅ Modèle français `vosk-model-small-fr-0.22` inclus
- 🎯 **Détection automatique Wayland/X11** pour l'injection de texte
- 🇫🇷 **Configuration française automatique** avec ponctuation
- 🚀 Prêt à l'emploi sans configuration

## Utilisation

### Package seul

```bash
nix run github:votre-utilisateur/nix-nerd-dictation
```

### Module NixOS

```nix
{
  inputs.nerd-dictation.url = "github:votre-utilisateur/nix-nerd-dictation";
  
  imports = [ inputs.nerd-dictation.nixosModules.default ];
  
  services.nerd-dictation = {
    enable = true;
    modelPath = "/path/to/vosk-model";
    audioBackend = "parec";  # ou "sox", "pw-cat"
    inputBackend = "xdotool"; # ou "ydotool", "dotool", "wtype"
    configScript = ''
      def text_replace_function(text):
        text = text.replace("new line", "\n")
        text = text.replace("tab", "\t")
        return text
    '';
  };
}
```

### Module Home Manager

```nix
{
  imports = [ inputs.nerd-dictation.homeManagerModules.default ];
  
  programs.nerd-dictation = {
    enable = true;
    modelPath = "/home/user/.local/share/vosk-model";
    keyBindings = {
      "super+d" = "nerd-dictation begin";
      "super+shift+d" = "nerd-dictation end";
      "super+ctrl+d" = "nerd-dictation suspend";
    };
    enableSystemdService = true;
  };
}
```

## Configuration

### Options principales

- `modelPath` : Chemin vers le modèle VOSK
- `audioBackend` : Backend audio (`parec`, `sox`, `pw-cat`)
- `inputBackend` : Backend d'entrée (`xdotool`, `ydotool`, `dotool`, `wtype`)
- `configScript` : Script Python de configuration personnalisé
- `timeout` : Timeout en millisecondes pour la reconnaissance vocale
- `idleTime` : Temps d'inactivité avant l'arrêt de l'enregistrement
- `convertNumbers` : Convertir les mots nombres en chiffres

### Détection automatique de l'environnement

Le package détecte automatiquement votre environnement graphique :
- **Wayland** (COSMIC, GNOME, Sway, etc.) → utilise `wtype`
- **X11** (i3, XFCE, etc.) → utilise `xdotool`

### Configuration française automatique

Au premier lancement, une configuration française est automatiquement créée dans `~/.config/nerd-dictation/nerd-dictation.py` qui inclut :

- **Ponctuation** : "virgule" → `,`, "point d'interrogation" → ` ?`, etc.
- **Symboles** : "arobase" → `@`, "pourcentage" → `%`, "plus" → `+`, etc.
- **Navigation** : "nouvelle ligne" → retour à la ligne, "tabulation" → tab

#### Exemples de dictée :
- "Bonjour virgule comment allez-vous point d'interrogation" → "Bonjour, comment allez-vous ?"
- "Mon email arobase exemple point com" → "Mon email @exemple.com"
- "Quarante-deux pour cent" → "42%"

### Raccourcis clavier (Home Manager)

Le module Home Manager peut configurer automatiquement les raccourcis clavier pour i3 et sway :

```nix
programs.nerd-dictation.keyBindings = {
  "ctrl+alt+d" = "nerd-dictation begin";
  "ctrl+alt+shift+d" = "nerd-dictation end";
};
```

### Service systemd

Le module NixOS crée un service système, tandis que le module Home Manager peut créer un service utilisateur optionnel.

## Alias shell

Le module Home Manager ajoute automatiquement des alias pratiques :
- `nd-begin` : Démarrer la dictée
- `nd-end` : Arrêter la dictée  
- `nd-suspend` : Suspendre/reprendre la dictée