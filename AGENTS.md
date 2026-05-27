# Agent Guidance

This repository is a public, reusable Home Manager flake for mail configuration. Treat it as generic infrastructure, not as a personal or host-specific config repository.

## Privacy Boundary

Do not add real account data to this repo:

- No real email addresses.
- No real names.
- No host names.
- No private mailbox names, client names, case names, or labels.
- No passwords, app passwords, API keys, or decrypted secret material.
- No private sops files or `.sops.yaml` policy from a consuming host repo.

Examples should use clearly fake values such as `example@example.invalid`, `Example User`, and `/run/secrets/example-mail-password`.

## Module Boundary

ApexMail owns reusable generation logic for:

- `mbsync` / `isyncrc`
- `msmtp` config
- `notmuch` config
- NeoMutt XDG config
- Per-account NeoMutt files
- Provider and folder presets

Consuming repositories own:

- Account choices
- Email addresses and real names
- Password commands
- Secret declarations
- sops/agenix/pass policy
- Encrypted named-mailboxes and case-specific NeoMutt snippets

Keep the public API under `apexMail` unless there is a deliberate migration plan.

## Render Backends

The default backend is `apexMail.renderBackend = "xdg"`. It writes generated files with `xdg.configFile` and does not require any secrets module.

Use `apexMail.renderBackend = "sops"` only through `homeManagerModules.sops`. That module imports the default module and adds `sops.templates` rendering for files that need placeholder substitution at activation time.

Important gotcha: do not pass `config.sops.placeholder.*` directly into `apexMail.accounts.*` when using the sops backend. `sops.placeholder` depends on `sops.templates`, and ApexMail's sops backend also defines `sops.templates`, so direct placeholders in account options can cause infinite recursion.

For the sops backend, pass sops key names instead:

```nix
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
```

The consuming repo must still declare the relevant `sops.secrets` keys. ApexMail must not declare host-specific secrets automatically.

## Password Handling

Keep `passwordCommand` as the password interface. Do not add a clear-text `password` option unless explicitly requested and carefully documented as Nix-store unsafe.

Safe pattern:

```nix
passwordCommand = "cat ${config.sops.secrets."work-password".path}";
```

Unsafe pattern:

```nix
passwordCommand = "printf '%s' 'actual-password'";
```

## NeoMutt Behavior

ApexMail writes `~/.config/neomutt/neomuttrc` directly. It intentionally does not install a wrapper that forces `neomutt -F ...`; plain NeoMutt should discover XDG config.

Keep private `named-mailboxes` and account-specific macros in consuming repos. For sops users, those should be encrypted snippets referenced by key name through `extraNeomuttConfig` when using the sops backend.

## Provider Presets

Provider and folder presets live in `modules/home-manager/presets.nix`. StartMail defaults are generic and safe to keep here. Do not add provider settings that embed personal account details.

For `provider = "custom"`, require explicit IMAP and SMTP settings. For `folderPreset = "custom"`, require explicit folder names.

## Verification

Run this after module changes:

```sh
nix flake check
```

If changing the sops backend, also verify from a consuming repo that imports `homeManagerModules.sops`, because the default flake check intentionally does not depend on sops-nix.

Known harmless warning:

```text
warning: unknown flake output 'homeManagerModules'
```

This is Nix warning about a custom flake output and is not a failed check.

## Editing Guidelines

- Prefer small changes that preserve the public API.
- Keep generated config logic deterministic and easy to inspect.
- Do not introduce backward-compatibility aliases unless there is a real external consumer need.
- Keep comments short and focused on non-obvious behavior, especially backend and sops recursion constraints.
