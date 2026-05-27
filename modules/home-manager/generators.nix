{ config, lib, presets }:

let
  optionalConfig = value: lib.optionalString (value != null && value != "") value;
  concatStanzas = f: xs: lib.concatStringsSep "\n" (map f xs);

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

  mkIsyncStores = value: a: ''
    IMAPStore ${a.name}-remote
    Host ${a.imapHost}
    Port ${toString a.imapPort}
    User ${value a.address}
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

  mkMsmtpStanza = value: a: ''
    account ${a.name}
    auth on
    from ${value a.address}
    host ${a.smtpHost}
    passwordeval ${a.passwordCommand}
    port ${toString a.smtpPort}
    tls on
    tls_starttls off
    tls_trust_file /etc/ssl/certs/ca-certificates.crt
    user ${value a.address}
  '';

  mkNeomuttAccountFile = value: a: ''
    set ssl_force_tls = yes
    set certificate_file=/etc/ssl/certs/ca-certificates.crt

    set crypt_autosign = no
    set crypt_opportunistic_encrypt = no
    set pgp_use_gpg_agent = yes
    set mbox_type = Maildir

    set sendmail='msmtpq --read-envelope-from --read-recipients'

    set folder='${config.xdg.dataHome}/mail/${a.name}'
    set from='${value a.address}'
    set postponed='+${a.draftsFolder}'
    set realname='${value a.realname}'
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

    ${optionalConfig (if a.extraNeomuttConfig != null then value a.extraNeomuttConfig else null)}
  '';

  mkNotmuchConfig = value: primaryAccount: ''
    [database]
    path=${config.xdg.dataHome}/mail

    [user]
    name=${value primaryAccount.realname}
    primary_email=${value primaryAccount.address}

    [new]
    tags=unread;inbox;
    ignore=.mbsyncstate;.uidvalidity;

    [search]
    exclude_tags=deleted;spam;

    [maildir]
    synchronize_flags=true
  '';
in
{
  inherit resolveAccount mkNeomuttAccountFile mkNotmuchConfig;

  mkAccountList = accounts:
    let
      resolved = map resolveAccount accounts;
      primary = lib.filter (a: a.primary) resolved;
      others = lib.filter (a: !a.primary) resolved;
    in
    primary ++ (lib.sortOn (a: a.name) others);

  mkIsyncrcContent = value: accountList:
    (concatStanzas (mkIsyncStores value) accountList) + "\n" + (concatStanzas mkIsyncChannel accountList);

  mkMsmtpConfigContent = value: accountList: primaryAccount:
    (lib.concatMapStrings (mkMsmtpStanza value) accountList) + "\naccount default : ${primaryAccount.name}\n";
}
