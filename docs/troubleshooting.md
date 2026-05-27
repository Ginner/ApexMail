# Troubleshooting

## Secret Values

ApexMail does not provide or require a secrets backend. If you use sops, import and configure `sops-nix` in the consuming Home Manager configuration and set `apexMail.renderBackend = "sops"`.

With the sops backend, pass sops key names for `address`, `realname`, and `extraNeomuttConfig`, not `config.sops.placeholder.*` values. Direct placeholders in account options can recurse because `sops.placeholder` depends on `sops.templates`, and the sops backend generates those templates.

## Missing Account Settings

If using `provider = "custom"`, set `imapHost`, `imapPort`, `smtpHost`, and `smtpPort`.

If using `folderPreset = "custom"`, set `archiveFolder`, `draftsFolder`, `sentFolder`, `trashFolder`, and `spamFolder`.

## NeoMutt Does Not Read Config

ApexMail writes `~/.config/neomutt/neomuttrc`. It does not install a wrapper. Confirm your NeoMutt build checks the XDG config path, or run:

```sh
neomutt -F ~/.config/neomutt/neomuttrc
```

## Passwords In Logs Or Store Paths

Passwords should only be referenced through `passwordCommand`. Do not put plaintext passwords directly in account options or `extraNeomuttConfig`.
