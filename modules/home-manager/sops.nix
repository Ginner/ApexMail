{
  config,
  lib,
  ...
}:

let
  cfg = config.apexMail;
  presets = import ./presets.nix;
  gen = import ./generators.nix { inherit config lib presets; };
  value = key: config.sops.placeholder.${key};

  accountList = gen.mkAccountList (lib.attrValues cfg.accounts);
  primaryAccount = lib.findFirst (a: a.primary) null accountList;
in
{
  imports = [ ./default.nix ];

  config = lib.mkIf (cfg.enable && cfg.renderBackend == "sops") {
    sops.templates = lib.mkMerge [
      (lib.mkIf cfg.mbsync.enable {
        "apexmail-isyncrc" = {
          path = "${config.xdg.configHome}/isyncrc";
          content = gen.mkIsyncrcContent value accountList;
        };
      })

      (lib.mkIf (cfg.msmtp.enable && primaryAccount != null) {
        "apexmail-msmtp-config" = {
          path = "${config.xdg.configHome}/msmtp/config";
          content = gen.mkMsmtpConfigContent value accountList primaryAccount;
        };
      })

      (lib.mkIf cfg.neomutt.enable (lib.listToAttrs (
        map (a: {
          name = "apexmail-neomutt-${a.name}";
          value = {
            path = "${config.xdg.configHome}/neomutt/${a.name}";
            content = gen.mkNeomuttAccountFile value a;
          };
        }) accountList
      )))

      (lib.mkIf (cfg.notmuch.enable && primaryAccount != null) {
        "apexmail-notmuch-config" = {
          path = "${config.xdg.configHome}/notmuch/default/config";
          content = gen.mkNotmuchConfig value primaryAccount;
        };
      })
    ];
  };
}
