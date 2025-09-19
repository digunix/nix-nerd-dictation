{
  description = "A Nix flake for nerd-dictation with NixOS and Home Manager modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nerd-dictation = pkgs.callPackage ./package.nix { };
      in
      {
        packages.default = nerd-dictation;
        packages.nerd-dictation = nerd-dictation;

        apps.default = flake-utils.lib.mkApp {
          drv = nerd-dictation;
          name = "nerd-dictation";
        };
      }
    ) // {
      nixosModules.default = import ./nixos-module.nix;
      nixosModules.nerd-dictation = import ./nixos-module.nix;
      
      homeManagerModules.default = import ./home-manager-module.nix;
      homeManagerModules.nerd-dictation = import ./home-manager-module.nix;
    };
}