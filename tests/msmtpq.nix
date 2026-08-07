{ pkgs }:

let
  fakeMsmtp = pkgs.symlinkJoin {
    name = "fake-msmtp";
    paths = [
      (pkgs.writeShellScriptBin "msmtp" ''
        ${pkgs.coreutils}/bin/cat >/dev/null
        exit "''${MOCK_MSMTP_RC:-0}"
      '')
      (pkgs.writeShellScriptBin "msmtp-queue" ''
        printf 'invoked\n' > "$MOCK_QUEUE_MARKER"
        exit "''${MOCK_QUEUE_RC:-0}"
      '')
    ];
  };
  wrapper = import ../modules/home-manager/msmtpq.nix {
    inherit pkgs;
    stateHome = "$TMPDIR/state";
    msmtp = fakeMsmtp;
  };
in
pkgs.runCommand "apexmail-msmtpq-test" { } ''
  export MOCK_QUEUE_MARKER="$TMPDIR/queue-invoked"

  export MOCK_MSMTP_RC=69
  if printf 'permanent failure\n' | ${wrapper}/bin/apexmail-msmtpq recipient@example.invalid; then
    echo "permanent failure unexpectedly returned success" >&2
    exit 1
  else
    rc=$?
    [ "$rc" -eq 69 ]
  fi
  ! compgen -G "$TMPDIR/state/msmtp/queue/*.mail" >/dev/null
  ! compgen -G "$TMPDIR/state/msmtp/queue/*.msmtp" >/dev/null

  export MOCK_MSMTP_RC=75
  printf 'temporary failure\n' | ${wrapper}/bin/apexmail-msmtpq recipient@example.invalid
  mail_files=("$TMPDIR/state/msmtp/queue/"*.mail)
  args_files=("$TMPDIR/state/msmtp/queue/"*.msmtp)
  [ "''${#mail_files[@]}" -eq 1 ]
  [ "''${#args_files[@]}" -eq 1 ]
  ${pkgs.gnugrep}/bin/grep -q 'temporary failure' "''${mail_files[0]}"
  ${pkgs.gnugrep}/bin/grep -q 'recipient@example.invalid' "''${args_files[0]}"

  export MOCK_MSMTP_RC=0
  export MOCK_QUEUE_RC=69
  printf 'successful current message\n' | ${wrapper}/bin/apexmail-msmtpq other@example.invalid
  [ -e "$MOCK_QUEUE_MARKER" ]
  mail_files=("$TMPDIR/state/msmtp/queue/"*.mail)
  [ "''${#mail_files[@]}" -eq 1 ]
  ${pkgs.gnugrep}/bin/grep -q 'temporary failure' "''${mail_files[0]}"

  touch "$out"
''
