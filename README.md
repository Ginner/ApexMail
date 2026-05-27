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

ApexMail does not depend on any secrets module. `address`, `realname`, `passwordCommand`, `signatureFile`, and `extraNeomuttConfig` are plain inputs supplied by the consuming configuration. Those values may be clear text, generated values, sops placeholders, agenix paths, `pass` commands, or anything else the host repo chooses.

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

    address = "work-address";
    realname = "work-realname";
    passwordCommand = "cat ${config.sops.secrets."work-password".path}";
    extraNeomuttConfig = "work-neomutt-extra-config";
  };
}
```

## Private NeoMutt Snippets

Named mailboxes and case-specific macros should stay in the consuming private or host-specific repository. If those snippets are stored in sops, declare the secret outside ApexMail and pass the key name as account config:

```nix
{ config, ... }:
{
  sops.secrets."work-neomutt-extra-config" = { };

  apexMail.accounts.work.extraNeomuttConfig = "work-neomutt-extra-config";
}
```

ApexMail treats `extraNeomuttConfig` as opaque NeoMutt text for the XDG backend and as a sops key name for the sops backend.

When using the sops backend, set `apexMail.renderBackend = "sops"` and pass sops key names for `address`, `realname`, and `extraNeomuttConfig`. ApexMail will render generated files through `sops.templates`, but it still does not declare or configure any secrets itself.

## Signatures

Signatures often contain personal data, so keep the signature file content in the consuming host repository. ApexMail disables signatures by default; point an account at a consuming-repo-managed signature file with `signatureFile`:

```nix
apexMail.accounts.work = {
  signatureFile = "${config.xdg.configHome}/neomutt/signature-work";
  signatureOnTop = false;
};
```

For the sops backend, render the signature file from the consuming repo with `sops.templates`, then pass that generated path to `signatureFile`. Keep `extraNeomuttConfig` for opaque private NeoMutt snippets such as named mailboxes and account-specific macros.

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
apexMail.neomutt.theme.enable
apexMail.neomutt.theme.useStylix
apexMail.neomutt.theme.colors
apexMail.neomutt.theme.extraConfig
apexMail.accounts.<name>
apexMail.accounts.<name>.signatureFile
apexMail.accounts.<name>.signatureOnTop
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

## NeoMutt Theming

ApexMail generates a mutt-wizard-like NeoMutt color theme by default:

```nix
apexMail.neomutt.theme.enable = true;
```

When `apexMail.neomutt.theme.useStylix = true`, ApexMail uses terminal ANSI color tokens (`color0` through `color15`) so the theme follows the terminal palette configured by Stylix. It does not emit direct `#rrggbb` colors because many NeoMutt builds, including the nixpkgs build, reject those unless direct color support is enabled.

If Stylix is not used, the generated theme falls back to named terminal colors such as `red`, `green`, `blue`, and `brightyellow`.

You can append or override NeoMutt color rules with:

```nix
apexMail.neomutt.theme.extraConfig = ''
  color status brightgreen default
'';
```

For a fully explicit palette, provide NeoMutt-supported color tokens keyed by `base00` through `base0F`:

```nix
apexMail.neomutt.theme.colors = {
  base00 = "color0";
  base05 = "color7";
  base08 = "color1";
  base0B = "color2";
  base0D = "color4";
};
```

Do not use `#rrggbb` values in `apexMail.neomutt.theme.colors` unless your NeoMutt build supports direct colors.

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
