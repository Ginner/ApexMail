{
  description = "Reusable Home Manager mail stack for mbsync, msmtp, notmuch, and NeoMutt";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeManagerModules.default = ./modules/home-manager;

      checks.${system}.example = (home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          self.homeManagerModules.default
          {
            home = {
              username = "apexmail-check";
              homeDirectory = "/home/apexmail-check";
              stateVersion = "25.11";
            };

            apexMail = {
              enable = true;
              accounts.example = {
                primary = true;
                provider = "startmail";
                folderPreset = "startmail";
                macroKey = "1";
                address = "example@example.invalid";
                realname = "Example User";
                passwordCommand = "cat /run/secrets/example-mail-password";
              };
            };
          }
        ];
      }).activationPackage;
    };
}
