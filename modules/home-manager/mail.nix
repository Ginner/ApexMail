{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.apexMail;
  presets = import ./presets.nix;

  enabledAccounts = lib.attrValues cfg.accounts;

  resolveAccount = a:
    let
      base = {
        imapHost = null;
        imapPort = null;
        smtpHost = null;
        smtpPort = null;
        archiveFolder = null;
        draftsFolder = null;
        sentFolder = null;
        trashFolder = null;
        spamFolder = null;
      };
      providerDefaults = presets.providers.${a.provider} or { };
      folderDefaults = presets.folders.${a.folderPreset} or { };
      explicitValues = lib.filterAttrs (_: value: value != null) a;
    in
    base // providerDefaults // folderDefaults // explicitValues // { extraNeomuttConfig = a.extraNeomuttConfig; };

  accountList =
    let
      resolved = map resolveAccount enabledAccounts;
      primary = lib.filter (a: a.primary) resolved;
      others = lib.filter (a: !a.primary) resolved;
    in
    primary ++ (lib.sortOn (a: a.name) others);

  primaryAccount = lib.findFirst (a: a.primary) null accountList;

  concatStanzas = f: xs: lib.concatStringsSep "\n" (map f xs);
  optionalConfig = value: lib.optionalString (value != null && value != "") value;

  fallbackColors = {
    base00 = "default";
    base01 = "black";
    base02 = "blue";
    base03 = "brightblack";
    base04 = "white";
    base05 = "default";
    base06 = "brightwhite";
    base07 = "brightwhite";
    base08 = "red";
    base09 = "yellow";
    base0A = "brightyellow";
    base0B = "green";
    base0C = "cyan";
    base0D = "blue";
    base0E = "magenta";
    base0F = "red";
  };

  # Stylix themes terminal ANSI colors. NeoMutt in nixpkgs does not support
  # direct #rrggbb colors, so use terminal color indexes instead.
  terminalColors = {
    base00 = "color0";
    base01 = "color0";
    base02 = "color8";
    base03 = "color8";
    base04 = "color7";
    base05 = "color7";
    base06 = "color15";
    base07 = "color15";
    base08 = "color1";
    base09 = "color3";
    base0A = "color11";
    base0B = "color2";
    base0C = "color6";
    base0D = "color4";
    base0E = "color5";
    base0F = "color9";
  };

  themeColors =
    if cfg.neomutt.theme.colors != null then
      fallbackColors // cfg.neomutt.theme.colors
    else if cfg.neomutt.theme.useStylix then
      terminalColors
    else
      fallbackColors;

  mkNeomuttTheme = c: ''
    # Theme
    mono bold bold
    mono underline underline
    mono indicator reverse
    mono error bold

    color normal ${c.base05} ${c.base00}
    color indicator ${c.base00} ${c.base0D}
    color status ${c.base0A} ${c.base00}
    color error ${c.base08} ${c.base00}
    color tilde ${c.base03} ${c.base00}
    color message ${c.base0C} ${c.base00}
    color markers ${c.base08} ${c.base00}
    color attachment ${c.base06} ${c.base00}
    color search ${c.base0E} ${c.base00}
    color hdrdefault ${c.base0B} ${c.base00}
    color quoted ${c.base0B} ${c.base00}
    color quoted1 ${c.base0D} ${c.base00}
    color quoted2 ${c.base0C} ${c.base00}
    color quoted3 ${c.base0A} ${c.base00}
    color quoted4 ${c.base08} ${c.base00}
    color quoted5 ${c.base0F} ${c.base00}
    color signature ${c.base0B} ${c.base00}
    color bold ${c.base07} ${c.base00}
    color underline ${c.base0D} ${c.base00}

    color sidebar_highlight ${c.base0D} ${c.base00}
    color sidebar_divider ${c.base03} ${c.base00}
    color sidebar_flagged ${c.base0A} ${c.base00}
    color sidebar_new ${c.base0B} ${c.base00}

    color index ${c.base05} ${c.base00} '.*'
    color index_author ${c.base08} ${c.base00} '.*'
    color index_number ${c.base0D} ${c.base00}
    color index_subject ${c.base0C} ${c.base00} '.*'

    color index ${c.base0A} ${c.base00} "~N"
    color index_author ${c.base08} ${c.base00} "~N"
    color index_subject ${c.base0C} ${c.base00} "~N"

    color index ${c.base05} ${c.base02} "~T"
    color index_author ${c.base08} ${c.base02} "~T"
    color index_subject ${c.base0C} ${c.base02} "~T"

    color index ${c.base0B} ${c.base00} "~F"
    color index_subject ${c.base0B} ${c.base00} "~F"
    color index_author ${c.base0B} ${c.base00} "~F"

    color header ${c.base0E} ${c.base00} "^From"
    color header ${c.base0C} ${c.base00} "^Subject"
    color header ${c.base06} ${c.base00} "^(CC|BCC)"
    color header ${c.base0D} ${c.base00} ".*"
    color body ${c.base08} ${c.base00} "[-.+_a-zA-Z0-9]+@[-.a-zA-Z0-9]+"
    color body ${c.base0D} ${c.base00} "(https?|ftp)://[-.,/%~_:?&=#a-zA-Z0-9]+"
    color body ${c.base0B} ${c.base00} "\`[^\`]*\`"
    color body ${c.base0D} ${c.base00} "^# .*"
    color body ${c.base0C} ${c.base00} "^## .*"
    color body ${c.base0B} ${c.base00} "^### .*"
    color body ${c.base0A} ${c.base00} "^(\t| )*(-|\\*) .*"
    color body ${c.base08} ${c.base00} "(BAD signature)"
    color body ${c.base0C} ${c.base00} "(Good signature)"
    color body ${c.base03} ${c.base00} "^gpg: Good signature .*"
    color body ${c.base0A} ${c.base00} "^gpg: "
    color body ${c.base0A} ${c.base08} "^gpg: BAD signature from.*"
    mono body bold "^gpg: Good signature"
    mono body bold "^gpg: BAD signature from.*"
  '';

  isyncrcContent = (concatStanzas mkIsyncStores accountList) + "\n" + (concatStanzas mkIsyncChannel accountList);
  msmtpConfigContent = (lib.concatMapStrings mkMsmtpStanza accountList) + "\naccount default : ${primaryAccount.name}\n";
  notmuchConfigContent = ''
    [database]
    path=${config.xdg.dataHome}/mail

    [user]
    name=${primaryAccount.realname}
    primary_email=${primaryAccount.address}

    [new]
    tags=unread;inbox;
    ignore=.mbsyncstate;.uidvalidity;

    [search]
    exclude_tags=deleted;spam;

    [maildir]
    synchronize_flags=true
  '';

  mkIsyncStores = a: ''
    IMAPStore ${a.name}-remote
    Host ${a.imapHost}
    Port ${toString a.imapPort}
    User ${a.address}
    PassCmd "${a.passwordCommand}"
    AuthMechs LOGIN
    TLSType IMAPS
    CertificateFile /etc/ssl/certs/ca-certificates.crt

    MaildirStore ${a.name}-local
    Subfolders Verbatim
    Path ${config.xdg.dataHome}/mail/${a.name}/
    Inbox ${config.xdg.dataHome}/mail/${a.name}/INBOX
  '';

  mkIsyncChannel = a: ''
    Channel ${a.name}
    Expunge Both
    Far :${a.name}-remote:
    Near :${a.name}-local:
    Patterns ${lib.concatStringsSep " " a.mbsyncPatterns}
    Create Both
    SyncState *
    MaxMessages 0
    ExpireUnread no
  '';

  mkMsmtpStanza = a: ''
    account ${a.name}
    auth on
    from ${a.address}
    host ${a.smtpHost}
    passwordeval ${a.passwordCommand}
    port ${toString a.smtpPort}
    tls on
    tls_starttls off
    tls_trust_file /etc/ssl/certs/ca-certificates.crt
    user ${a.address}
  '';

  mkNeomuttAccountFile = a: ''
    set ssl_force_tls = yes
    set certificate_file=/etc/ssl/certs/ca-certificates.crt

    set crypt_autosign = no
    set crypt_opportunistic_encrypt = no
    set pgp_use_gpg_agent = yes
    set mbox_type = Maildir
    set sort = "threads"

    set sendmail='msmtpq --read-envelope-from --read-recipients'

    set sidebar_visible = yes
    set sidebar_short_path = yes
    set sidebar_width = 28
    set sidebar_format = '%D%* %?F? %F? %?N?%N/?%?S?%S?'

    set folder='${config.xdg.dataHome}/mail/${a.name}'
    set from='${a.address}'
    set postponed='+${a.draftsFolder}'
    set realname='${a.realname}'
    set record='+${a.sentFolder}'
    set spoolfile='+INBOX'
    set trash='+${a.trashFolder}'

    macro index,pager gi "<change-folder>=INBOX<enter>" "go to inbox"
    macro index,pager Mi ";<save-message>=INBOX<enter>" "move mail to inbox"
    macro index,pager Ci ";<copy-message>=INBOX<enter>" "copy mail to inbox"
    macro index,pager gd "<change-folder>=${a.draftsFolder}<enter>" "go to drafts"
    macro index,pager Md ";<save-message>=${a.draftsFolder}<enter>" "move mail to drafts"
    macro index,pager Cd ";<copy-message>=${a.draftsFolder}<enter>" "copy mail to drafts"
    macro index,pager gj "<change-folder>=${a.spamFolder}<enter>" "go to junk"
    macro index,pager Mj ";<save-message>=${a.spamFolder}<enter>" "move mail to junk"
    macro index,pager Cj ";<copy-message>=${a.spamFolder}<enter>" "copy mail to junk"
    macro index,pager gt "<change-folder>=${a.trashFolder}<enter>" "go to trash"
    macro index,pager Mt ";<save-message>=${a.trashFolder}<enter>" "move mail to trash"
    macro index,pager Ct ";<copy-message>=${a.trashFolder}<enter>" "copy mail to trash"
    macro index,pager gs "<change-folder>=${a.sentFolder}<enter>" "go to sent"
    macro index,pager Ms ";<save-message>=${a.sentFolder}<enter>" "move mail to sent"
    macro index,pager Cs ";<copy-message>=${a.sentFolder}<enter>" "copy mail to sent"
    macro index,pager ga "<change-folder>=${a.archiveFolder}<enter>" "go to archive"
    macro index,pager Ma ";<save-message>=${a.archiveFolder}<enter>" "move mail to archive"
    macro index,pager Ca ";<copy-message>=${a.archiveFolder}<enter>" "copy mail to archive"

    unset signature

    set nm_default_uri = "notmuch://${config.xdg.dataHome}/mail"
    virtual-mailboxes "My INBOX" "notmuch://?query=tag%3Ainbox"

    ${optionalConfig a.extraNeomuttConfig}
  '';

  mkNeomuttrc = ''
    set nobeep
    set allow_ansi
    set mbox_type = Maildir
    set folder = "${config.xdg.dataHome}/mail"
    set sort = reverse-last-date
    set sort_aux = reverse-last-date
    set sort_re
    set use_threads = threads
    set uncollapse_jump
    set charset = "utf-8"
    set send_charset = "utf-8:iso-8859-1:us-ascii"
    set pager_index_lines = 15
    set pager_context = 3
    set pager_stop
    set menu_scroll
    set tilde
    unset markers
    set abort_key = "<Esc>"
    set mail_check_stats
    set mailcap_path = "${config.xdg.configHome}/neomutt/mailcap"

    set sidebar_visible
    set sidebar_short_path
    set sidebar_width = 28
    set sidebar_format = '%D%* %?F? %F? %?N?%N/?%?S?%S?'
    set sidebar_divider_char = " | "
    set sidebar_indent_string = "  "
    set sidebar_next_new_wrap
    set sidebar_sort_method = unsorted

    bind index,pager i noop
    bind attach,browser,index,pager g noop
    bind index,pager M noop
    bind index,pager C noop
    bind index \Cf noop
    bind editor <space> noop
    bind index h noop
    bind index j next-entry
    bind index k previous-entry
    bind attach <return> view-mailcap
    bind attach l view-mailcap
    bind pager,attach h exit
    bind pager j next-line
    bind pager k previous-line
    bind pager l view-attachments
    bind index L limit
    bind index l display-message
    bind index,query <space> tag-entry
    bind index,pager H view-raw-message
    bind browser l select-entry
    bind index,pager S sync-mailbox
    bind pager G bottom
    bind pager gg top
    bind index gg first-entry
    bind attach,browser,index G last-entry
    bind attach,browser,index gg first-entry
    bind editor <tab> complete-query

    macro index,pager \Cj '<sidebar-next><sidebar-open>'
    macro index,pager \Ck '<sidebar-prev><sidebar-open>'
    macro index,pager U '<enter-command>set pipe_decode = yes<enter><pipe-message>urlscan<enter><enter-command>set pipe_decode = no<enter>' "view URLs"
    macro attach s "<save-entry><bol>$HOME/Downloads/<eol>" "Save to Downloads folder"
    macro browser h '<change-dir><kill-line>..<enter>' "Go to parent folder"
    macro index O "<shell-escape>${cfg.neomutt.mailsyncCommand}<enter>" "run mailsync to sync all mail"

    ${lib.optionalString cfg.neomutt.enableKhard ''
      set query_command = "khard email --parsable '%s'"
      macro index,pager a "<pipe-message>khard add-email<return>" "add sender to khard contacts"
    ''}

    ${lib.optionalString cfg.neomutt.theme.enable (mkNeomuttTheme themeColors)}

    ${optionalConfig cfg.neomutt.theme.extraConfig}

    ${lib.concatStringsSep "\n" (
      map (a: ''macro index,pager i${a.macroKey} '<sync-mailbox><enter-command>source ${config.xdg.configHome}/neomutt/${a.name}<enter><change-folder>!<enter>;<check-stats>' "switch to ${a.name}"'') accountList
    )}

    ${lib.optionalString (primaryAccount != null) ''
      source ${config.xdg.configHome}/neomutt/${primaryAccount.name}
    ''}
  '';

  accountType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Account name, derived from the attrset key by default.";
        };

        primary = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this account is the primary mail account.";
        };

        provider = lib.mkOption {
          type = lib.types.enum [ "startmail" "custom" ];
          default = "custom";
          description = "Provider preset to use for IMAP and SMTP settings.";
        };

        folderPreset = lib.mkOption {
          type = lib.types.enum [ "startmail" "generic" "custom" ];
          default = "custom";
          description = "Folder preset to use for mail folder names.";
        };

        imapHost = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "IMAP server hostname. Required when provider is custom.";
        };

        imapPort = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "IMAP port. Required when provider is custom.";
        };

        smtpHost = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SMTP server hostname. Required when provider is custom.";
        };

        smtpPort = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "SMTP port. Required when provider is custom.";
        };

        mbsyncPatterns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "*"
            "!Spam"
          ];
          description = "mbsync channel Patterns entries.";
        };

        archiveFolder = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Archive folder name. Required when folderPreset is custom.";
        };

        draftsFolder = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Drafts folder name. Required when folderPreset is custom.";
        };

        sentFolder = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Sent folder name. Required when folderPreset is custom.";
        };

        trashFolder = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Trash folder name. Required when folderPreset is custom.";
        };

        spamFolder = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Spam/junk folder name. Required when folderPreset is custom.";
        };

        macroKey = lib.mkOption {
          type = lib.types.str;
          description = ''
            NeoMutt account-switching key suffix. For example, "1" creates i1.
          '';
        };

        address = lib.mkOption {
          type = lib.types.str;
          description = ''
            Account email address. This may be a plain value or a placeholder
            provided by the consuming configuration.
          '';
        };

        realname = lib.mkOption {
          type = lib.types.str;
          description = ''
            Account display name. This may be a plain value or a placeholder
            provided by the consuming configuration.
          '';
        };

        passwordCommand = lib.mkOption {
          type = lib.types.str;
          description = ''
            Runtime command that prints the account password or app password.
            Do not put the password itself in this option.
          '';
        };

        extraNeomuttConfig = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
          description = ''
            Additional per-account NeoMutt config. Host repos may pass any text
            here, including a placeholder from a secrets module.
          '';
        };
      };
    }
  );
in
{
  options.apexMail = {
    enable = lib.mkEnableOption "ApexMail mail stack";

    mbsync.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate mbsync configuration and install isync.";
    };

    renderBackend = lib.mkOption {
      type = lib.types.enum [ "xdg" "sops" ];
      default = "xdg";
      description = ''
        Backend used to render generated config files. Use "sops" when account
        values contain sops placeholders that must be substituted at activation.
      '';
    };

    msmtp.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate msmtp configuration and install msmtp.";
    };

    notmuch.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate notmuch configuration and install notmuch.";
    };

    neomutt = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Generate NeoMutt XDG configuration and install NeoMutt.";
      };

      mailsyncCommand = lib.mkOption {
        type = lib.types.str;
        default = "mbsync -a";
        description = "Command used by the NeoMutt sync macro.";
      };

      enableKhard = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable khard query and add-sender macros.";
      };

      theme = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable generated NeoMutt color rules.";
        };

        useStylix = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use Stylix Base16 colors when they are available.";
        };

        colors = lib.mkOption {
          type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
          default = null;
          description = ''
            Optional NeoMutt color token attrset keyed by base00-base0F. Values
            must be NeoMutt-supported color names, such as color0 or red, not
            #rrggbb direct colors.
          '';
        };

        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Extra NeoMutt color config appended after the generated theme.";
        };
      };
    };

    accounts = lib.mkOption {
      type = lib.types.attrsOf accountType;
      default = { };
      description = "Email accounts managed by ApexMail.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      let
        primaryAccounts = lib.filter (a: a.primary) accountList;
        macroKeys = map (a: a.macroKey) accountList;
        hasProviderConfig = a: a.imapHost != null && a.imapPort != null && a.smtpHost != null && a.smtpPort != null;
        hasFolderConfig = a:
          a.archiveFolder != null
          && a.draftsFolder != null
          && a.sentFolder != null
          && a.trashFolder != null
          && a.spamFolder != null;
      in
      [
        {
          assertion = accountList != [ ];
          message = "apexMail: at least one account must be configured.";
        }
        {
          assertion = lib.length primaryAccounts == 1;
          message = "apexMail: exactly one account must have primary = true.";
        }
        {
          assertion = lib.length (lib.unique macroKeys) == lib.length macroKeys;
          message = "apexMail: account macroKey values must be unique.";
        }
      ]
      ++ map (a: {
        assertion = hasProviderConfig a;
        message = "apexMail.accounts.${a.name}: provider settings are incomplete.";
      }) accountList
      ++ map (a: {
        assertion = hasFolderConfig a;
        message = "apexMail.accounts.${a.name}: folder settings are incomplete.";
      }) accountList;

    home.packages = lib.optionals cfg.mbsync.enable [ pkgs.isync ]
      ++ lib.optionals cfg.msmtp.enable [ pkgs.msmtp ]
      ++ lib.optionals cfg.notmuch.enable [ pkgs.notmuch ]
      ++ lib.optionals cfg.neomutt.enable (with pkgs; [
        neomutt
        gnupg
        lynx
        urlscan
        w3m
      ]);

    xdg.configFile = lib.mkMerge [
      (lib.mkIf (cfg.renderBackend == "xdg" && cfg.mbsync.enable) {
        "isyncrc".text = isyncrcContent;
      })

      (lib.mkIf (cfg.renderBackend == "xdg" && cfg.msmtp.enable && primaryAccount != null) {
        "msmtp/config".text = msmtpConfigContent;
      })

      (lib.mkIf cfg.neomutt.enable (
        {
          "neomutt/mailcap".text = ''
        text/html; ${pkgs.lynx}/bin/lynx -dump -width=120 -stdin; nametemplate=%s.html; copiousoutput
        text/html; ${pkgs.w3m}/bin/w3m -dump -cols 120 -T text/html -I %{charset} -O utf-8; copiousoutput
      '';

          "neomutt/neomuttrc".text = mkNeomuttrc;
        }
        // lib.listToAttrs (
          map (a: {
            name = "neomutt/${a.name}";
            value = lib.mkIf (cfg.renderBackend == "xdg") {
              text = mkNeomuttAccountFile a;
            };
          }) accountList
        )
      ))

      (lib.mkIf (cfg.renderBackend == "xdg" && cfg.notmuch.enable && primaryAccount != null) {
        "notmuch/default/config".text = notmuchConfigContent;
      })
    ];
  };
}
