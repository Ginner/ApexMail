# Migration

## From ApexOS Local Modules

1. Add this flake as an input in the host configuration flake.
2. Import `inputs.apex-mail.homeManagerModules.default` in Home Manager.
3. Keep `sops-nix.homeManagerModules.sops` imported by the consuming repo if you use sops there.
4. Keep `sops.defaultSopsFile`, `sops.age.keyFile`, `.sops.yaml`, and encrypted mail secrets in the consuming repo.
5. Replace `myHomeModules.services.email` with `apexMail`.
6. Replace `myHomeModules.tuiPrograms.neomutt.enable` with `apexMail.neomutt.enable`.
7. Move encrypted named-mailboxes handling to host/user config with `extraNeomuttConfig`.
8. Build the host and test `mbsync -a`, `notmuch new`, `neomutt`, and sending mail.

## Example ApexOS Shape

```nix
{ config, inputs, ... }:
{
  imports = [
    inputs.apex-mail.homeManagerModules.default
  ];

  sops.secrets."work-neomutt-extra-config" = { };
  sops.secrets."work-password" = { };

  apexMail = {
    enable = true;
    renderBackend = "sops";

    accounts.work = {
      primary = true;
      provider = "startmail";
      folderPreset = "startmail";
      macroKey = "1";
      address = "work-address";
      realname = "work-realname";
      passwordCommand = "cat ${config.sops.secrets."work-password".path}";
      extraNeomuttConfig = "work-neomutt-extra-config";
    };
  };
}
```
