{
  description = "My Nix(OS) configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hardware.url = "github:nixos/nixos-hardware";

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/nur";

    nixtest.url = "github:jetpack-io/nixtest";

    nix-index.url = "github:Mic92/nix-index-database";

    hosts = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };

    wallpapers = {
      url = "github:chabitblunk/wallpapers";
      flake = false;
    };
  };

  outputs = inputs @ { self, nixpkgs, home-manager, ... }:
    let
      user = "xfbm";
      
      secrets = import ./secrets;
      dotfiles = import ./dotfiles;

      hosts = [{ host = "gamergirl", extraOverlays = []; extraModules = []; timezone = secrets.main_timezone; location = secrets.main_location; }];

      hardwares = [
        { hardware = "pc", stateVersion = "23.05"; }
        # { hardware = "laptop"; stateVersion = "23.05"; } for the macbook
      ];

      systems = [
        { system = "x86_64-linux"; }
        # { system = "aarch64-darwin"; } for the macbook
      ];

      commonInherits = {
        inherit (nixpkgs) lib;
        inherit inputs nixpkgs home-manager;
        inherit user secrets dotfiles hosts hardwares systems;
      };
    in
    {
      nixosConfigurations = import ./hosts (commonInherits // {
        isNixOS = true;
        isIso = false;
        isHardware = true;
      });

      homeConfigurations = import ./hosts (commonInherits // {
        isNixOS = false;
        isIso = false;
        isHardware = false;
      });

      isoConfigurations = import ./hosts (commonInherits // {
        isNixOS = true;
        isIso = true;
        isHardware = false;
        user = "nixos";
      });

      nixosNoHardwareConfigurations = import ./hosts (commonInherits // {
        isNixOS = true;
        isIso = false;
        isHardware = false;
      });

      deploy = {
        magicRollback = true;
        autoRollback = true;

        nodes = builtins.mapAttrs
          (_: nixosConfig: {
            hostname = "${nixosConfig.config.networking.hostName}";

            profiles.system = {
              user = "root";
              path = inputs.deploy-rs.lib.${nixosConfig.config.nixpkgs.system}.activate.nixos nixosConfig;
            };
          })
          self.nixosConfigurations;
      };

      # This is highly advised, and will prevent many possible mistakes
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;

      tests = inputs.nixtest.run ./.;
    }
}
