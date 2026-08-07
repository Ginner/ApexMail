{
  pkgs,
  stateHome,
  msmtp ? pkgs.msmtp,
}:

pkgs.writeShellScriptBin "apexmail-msmtpq" ''
  queue_dir="${stateHome}/msmtp/queue"
  log_file="${stateHome}/msmtp/queue.log"
  lock_dir="$queue_dir/.lock"

  ${pkgs.coreutils}/bin/mkdir -p "$queue_dir"
  ${pkgs.coreutils}/bin/chmod 0700 "$queue_dir"

  locked=
  cleanup() {
    if [ -n "$locked" ]; then
      ${pkgs.coreutils}/bin/rmdir "$lock_dir"
      locked=
    fi
  }
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  attempts=0
  while ! ${pkgs.coreutils}/bin/mkdir "$lock_dir" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 240 ]; then
      printf '%s\n' "apexmail-msmtpq: timed out waiting for queue lock $lock_dir" >&2
      exit 75
    fi
    ${pkgs.coreutils}/bin/sleep 1
  done
  locked=1

  id="$(${pkgs.coreutils}/bin/date +%Y-%m-%d-%H.%M.%S)"
  while [ -e "$queue_dir/$id.mail" ] || [ -e "$queue_dir/$id.msmtp" ]; do
    id="$id-1"
  done
  mail_file="$queue_dir/$id.mail"
  args_file="$queue_dir/$id.msmtp"

  ${pkgs.coreutils}/bin/cat > "$mail_file"
  : > "$args_file"
  for arg in "$@"; do
    printf '%s ' "$arg" >> "$args_file"
  done
  printf '\n' >> "$args_file"

  ${msmtp}/bin/msmtp "$@" < "$mail_file"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    ${pkgs.coreutils}/bin/rm -f "$mail_file" "$args_file"
    cleanup
    trap - EXIT

    # A stale queue failure must not turn this successful submission into a failure.
    MSMTPQ_Q="$queue_dir" MSMTPQ_LOG="$log_file" \
      ${msmtp}/bin/msmtp-queue -r >> "$log_file" 2>&1 || true
    exit 0
  fi

  if [ "$rc" -eq 75 ]; then
    printf '%s : mail queued after temporary delivery failure: [ %s ]\n' \
      "$(${pkgs.coreutils}/bin/date +'%Y %d %b %H:%M:%S')" "$id" >> "$log_file"
    printf '%s\n' "apexmail-msmtpq: temporary delivery failure; message queued as $id" >&2
    exit 0
  fi

  ${pkgs.coreutils}/bin/rm -f "$mail_file" "$args_file"
  printf '%s\n' "apexmail-msmtpq: permanent delivery failure; message was not queued" >&2
  exit "$rc"
''
