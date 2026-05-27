# ApexMail

ApexMail is a reusable Home Manager mail stack for `mbsync`, `msmtp`, `notmuch`, and NeoMutt.

The flake is intended to be public. Do not put email addresses, real names, passwords, host names, private mailbox names, case names, client names, or other personal data in this repository.

## Usage

Import the Home Manager module from a consuming flake:

```nix
{
  inputs.apex-mail.url = "git+https://example.invalid/ApexMail";

  outputs = { apex-mail, ... }@inputs: {
    # In your Home Manager module imports:
    imports = [
      apex-mail.homeManagerModules.default
    ];
  };
}
```

Configure accounts in the host or user-specific repository:

```nix
{
  apexMail = {
    enable = true;
    renderBackend = "sops";

    accounts.work = {
      primary = true;
      provider = "startmail";
      folderPreset = "startmail";
      macroKey = "1";

      address = "person@example.invalid";
      realname = "Person Example";
      passwordCommand = "cat /run/secrets/work-mail-password";
    };
  };
}
```

ApexMail does not depend on any secrets module. `address`, `realname`, `passwordCommand`, and `extraNeomuttConfig` are plain inputs supplied by the consuming configuration. Those values may be clear text, generated values, sops placeholders, agenix paths, `pass` commands, or anything else the host repo chooses.

Do not put the password itself in `passwordCommand`. Use a command that prints the password at runtime.

## Sops Example

If the consuming repo uses sops-nix, keep all sops setup there:

```nix
{ config, ... }:
{
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/email.yaml;
  };

  sops.secrets."work-password" = { };
  sops.secrets."work-neomutt-extra-config" = { };

  apexMail.accounts.work = {
    primary = true;
    provider = "startmail";
    folderPreset = "startmail";
    macroKey = "1";

    address = config.sops.placeholder."work-address";
    realname = config.sops.placeholder."work-realname";
    passwordCommand = "cat ${config.sops.secrets."work-password".path}";
    extraNeomuttConfig = config.sops.placeholder."work-neomutt-extra-config";
  };
}
```

## Private NeoMutt Snippets

Named mailboxes and case-specific macros should stay in the consuming private or host-specific repository. If those snippets are stored in sops, declare the secret outside ApexMail and pass the placeholder as account config:

```nix
{ config, ... }:
{
  sops.secrets."work-neomutt-extra-config" = { };

  apexMail.accounts.work.extraNeomuttConfig =
    config.sops.placeholder."work-neomutt-extra-config";
}
```

ApexMail treats `extraNeomuttConfig` as opaque NeoMutt text. It does not assume whether the value is public text, a sops placeholder, or omitted.

When using sops placeholders, set `apexMail.renderBackend = "sops"`. ApexMail will render generated files through `sops.templates`, but it still does not declare or configure any secrets itself.

## Options

Top-level namespace:

```nix
apexMail.enable
apexMail.renderBackend
apexMail.mbsync.enable
apexMail.msmtp.enable
apexMail.notmuch.enable
apexMail.neomutt.enable
apexMail.neomutt.mailsyncCommand
apexMail.neomutt.enableKhard
apexMail.accounts.<name>
```

Supported provider presets:

```nix
"startmail"
"custom"
```

Supported folder presets:

```nix
"startmail"
"generic"
"custom"
```

For `custom`, provide explicit IMAP, SMTP, and folder settings on the account.

## Generated Files

ApexMail writes these files:

```text
~/.config/isyncrc
~/.config/msmtp/config
~/.config/neomutt/neomuttrc
~/.config/neomutt/mailcap
~/.config/neomutt/<account>
~/.config/notmuch/default/config
```

NeoMutt is configured through XDG files directly. No wrapper is installed; plain `neomutt` is expected to discover `~/.config/neomutt/neomuttrc`.
