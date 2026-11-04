#!/usr/bin/env bash
# nixctl: the one command for changing this NixOS computer.
# Lives in the config repo as tools/nixctl.sh. modules/core/nixctl.nix
# installs it. Every command ends with a RESULT: line, and usually a
# NEXT: line that says what to do next.
set -euo pipefail

NIXCTL_VERSION=1
SELF=/run/current-system/sw/bin/nixctl

say() { printf '%s\n' "$*"; }
ok() {
  say "RESULT: OK $1"
  if [[ -n ${2:-} ]]; then say "NEXT: $2"; fi
  exit 0
}
fail() {
  say "RESULT: FAIL $1"
  if [[ -n ${2:-} ]]; then say "NEXT: $2"; fi
  exit 1
}

# ---------------------------------------------------------------------------
# Root part. Runs through `sudo nixctl _root ...`. sudo clears the
# environment, so this part takes only explicit arguments and never reads
# the repo.
# ---------------------------------------------------------------------------

store_system_ok() {
  [[ $1 =~ ^/nix/store/[a-z0-9]{32}-nixos-system-[^/]+$ && -x $1/bin/switch-to-configuration ]]
}

# switch-to-configuration runs in its own systemd unit, the way
# nixos-rebuild does it, so a restarted desktop or terminal cannot kill it
# halfway through.
run_stc() {
  systemd-run -E LOCALE_ARCHIVE -E NIXOS_INSTALL_BOOTLOADER -E NIXOS_NO_CHECK --collect \
    --no-ask-password --pipe --quiet --service-type=exec \
    --unit=nixctl-switch-to-configuration -- "$1/bin/switch-to-configuration" "$2"
}

bad_units() {
  systemctl list-units --state=failed,auto-restart --plain --no-legend --no-pager 2>/dev/null |
    awk '{print $1}' | sort -u || true
}

settle() {
  local _
  for _ in $(seq 1 60); do
    [[ -z $(systemctl list-jobs --no-legend 2>/dev/null) ]] && break
    sleep 1
  done
  # A service that crashes a few seconds after it starts shows up here.
  sleep 8
}

disarm() {
  systemctl stop nixctl-revert.timer >/dev/null 2>&1 || true
  systemctl reset-failed nixctl-revert.service nixctl-revert.timer >/dev/null 2>&1 || true
}

root_apply_system() {
  local new=$1 old before after newbad u
  store_system_ok "$new" || fail "not a NixOS system path: $new"
  old=$(readlink -f /run/current-system)
  before=$(bad_units)

  # Dead-man switch: if this script dies before it finishes, the old
  # system comes back by itself after 5 minutes.
  disarm
  systemd-run --quiet --unit=nixctl-revert --on-active=300 \
    --timer-property=AccuracySec=5s "$old/bin/switch-to-configuration" test

  say "== test: activating the new system (not permanent yet)"
  if ! run_stc "$new" test; then
    say "== activation reported errors, going back to the old system"
    run_stc "$old" test || true
    disarm
    say "ROLLED BACK"
    return 1
  fi

  say "== health check: waiting for services to settle"
  settle
  after=$(bad_units)
  newbad=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d')
  if [[ -n $newbad ]]; then
    say "== these services broke after the change:"
    for u in $newbad; do
      say "-- $u (last log lines)"
      journalctl -u "$u" -b --no-pager -n 15 -o cat 2>/dev/null || true
    done
    say "== going back to the old system"
    run_stc "$old" test || true
    disarm
    say "BROKEN UNITS: $(tr '\n' ' ' <<<"$newbad")"
    say "ROLLED BACK"
    return 1
  fi

  say "== healthy, making it permanent"
  disarm
  nix-env -p /nix/var/nix/profiles/system --set "$new"
  run_stc "$new" switch
  say "SWITCHED"
}

root_rollback() {
  nix-env -p /nix/var/nix/profiles/system --rollback
  run_stc "$(readlink -f /nix/var/nix/profiles/system)" switch
  say "SWITCHED"
}

root_clean() {
  local keep=$1
  [[ $keep =~ ^[0-9]+$ && $keep -ge 2 ]] || fail "keep must be a number of 2 or more"
  nix-env -p /nix/var/nix/profiles/system --delete-generations "+$keep"
  nix-collect-garbage
  # Rewrites the boot menu so deleted generations disappear from it.
  run_stc "$(readlink -f /nix/var/nix/profiles/system)" boot
}

if [[ ${1:-} == _root ]]; then
  [[ $EUID -eq 0 ]] || fail "_root must run as root"
  shift
  exec 9>/run/nixctl.lock
  flock -n 9 || fail "another nixctl is running" "wait a minute, then try again"
  case ${1:-} in
    apply-system) root_apply_system "${2:?}" ;;
    rollback) root_rollback ;;
    clean) root_clean "${2:-5}" ;;
    *) fail "unknown root action" ;;
  esac
  exit $?
fi

# ---------------------------------------------------------------------------
# User part. Runs as the normal user inside the config repo.
# ---------------------------------------------------------------------------

REPO=${NIXCTL_REPO:-/etc/nixos}
HOST=${NIXCTL_HOST:-$(hostname)}
SIM=${NIXCTL_SIMULATE:-0}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/nixctl
LOG=$STATE/last.log
HOSTFILE=hosts/$HOST/default.nix
PKGFILE=hosts/$HOST/packages.nix
FLAKE_ATTR=".#nixosConfigurations.$HOST"

mkdir -p "$STATE"
cd "$REPO" 2>/dev/null || fail "config repo $REPO not found" "set NIXCTL_REPO to the repo folder"
[[ -f $HOSTFILE ]] || fail "no $HOSTFILE in $REPO" "this repo is not in the nixctl layout yet; ask Claude to run the nixos-managing setup"

lock() {
  exec 8>"$STATE/lock"
  flock -n 8 || fail "another nixctl is running" "wait a minute, then try again"
}

as_root() {
  if [[ $SIM == 1 ]]; then
    say "(simulated) sudo nixctl _root $*"
    if [[ $1 == apply-system && -n ${NIXCTL_SIMULATE_FAIL_UNIT:-} ]]; then
      say "== these services broke after the change:"
      say "-- $NIXCTL_SIMULATE_FAIL_UNIT (last log lines)"
      say "(simulated) $NIXCTL_SIMULATE_FAIL_UNIT: Main process exited, code=exited, status=1/FAILURE"
      say "BROKEN UNITS: $NIXCTL_SIMULATE_FAIL_UNIT"
      say "ROLLED BACK"
      return 1
    fi
    say "SWITCHED"
    return 0
  fi
  sudo --non-interactive "$SELF" _root "$@"
}

git_q() { git -C "$REPO" "$@"; }

commit() {
  local msg=$1
  git_q add -A
  if git_q diff --cached --quiet; then return 0; fi
  if [[ -z $(git_q config user.email || true) ]]; then
    git_q -c user.name=nixctl -c user.email=nixctl@localhost commit -q -m "nixctl: $msg"
  else
    git_q commit -q -m "nixctl: $msg"
  fi
  say "== saved in git: nixctl: $msg"
}

# Turns a Nix error log into: the error line, the code around it, the repo
# file and line, and a hint for the NEXT: line (in HINT).
HINT=""
explain_nix_error() {
  local log=$1 msg loc="" f l opt
  msg=$(grep -E '^[[:space:]]*error:' "$log" | sed -E 's/^[[:space:]]*error:[[:space:]]*//' | grep -v '^$' | tail -1)
  [[ -n $msg ]] || msg=$(grep -vE '^[[:space:]]*$' "$log" | tail -1)
  while IFS= read -r l; do
    f=${l%%:*}
    if [[ -f $REPO/$f ]]; then loc=$l; fi
  done < <(grep -oE '(/nix/store/[a-z0-9]{32}-source|'"$REPO"')/[^:[:space:]'"'"'`]+\.nix(:[0-9]+:[0-9]+)?' "$log" |
    sed -E 's#^/nix/store/[a-z0-9]{32}-source/##; s#^'"$REPO"'/##')
  say "ERROR: $msg"
  # The numbered code lines Nix prints under the last error.
  awk '/^[[:space:]]*error:/ {buf = ""; n = 0; next} /^[[:space:]]+[0-9]+\|/ && n < 4 {buf = buf $0 "\n"; n++} END {printf "%s", buf}' "$log"
  if [[ -n $loc ]]; then say "WHERE: $loc"; fi
  HINT="fix the file and line in WHERE, then run nixctl check"
  if [[ $msg =~ The\ option\ .([A-Za-z0-9_.\<\>-]+).\ does\ not\ exist ]]; then
    opt=${BASH_REMATCH[1]}
    HINT="that option name is wrong; run nixctl option ${opt%.*} to see the real names, fix ${loc:-the module}, then nixctl check"
  elif [[ $msg == *"undefined variable"* ]]; then
    HINT="a word in ${loc:-the module} is misspelled or not defined; fix it, then nixctl check"
  elif [[ $msg == *"is not of type"* ]]; then
    HINT="wrong kind of value; run nixctl option NAME to see the type it needs, fix ${loc:-the module}, then nixctl check"
  elif [[ $msg == *"syntax error"* ]]; then
    HINT="broken Nix syntax (often a missing ; or }) at WHERE; fix it, then nixctl check"
  elif [[ $msg == *"does not exist"* && $msg == *"path"* ]]; then
    HINT="a file is missing or not added to git; check the path, then nixctl check"
  fi
}

guards() {
  local changed added
  changed=$(git_q diff HEAD --name-only; git_q ls-files --others --exclude-standard)
  if grep -qE '(^|/)hardware-configuration\.nix$' <<<"$changed" && [[ ${NIXCTL_ALLOW_HARDWARE:-0} != 1 ]]; then
    fail "hardware-configuration.nix was changed; it must stay as generated" "run: git -C $REPO checkout HEAD -- $(grep -E 'hardware-configuration\.nix$' <<<"$changed" | head -1)"
  fi
  if grep -qE '^secrets/' <<<"$changed" && [[ ${NIXCTL_ALLOW_SECRETS:-0} != 1 ]]; then
    fail "files in secrets/ were changed; only Riley changes secrets" "run: nixctl undo"
  fi
  if grep -qE '^flake\.lock$' <<<"$changed" && [[ ${NIXCTL_ALLOW_LOCK:-0} != 1 ]]; then
    fail "flake.lock was changed by hand" "run: git -C $REPO checkout HEAD -- flake.lock, then use nixctl update"
  fi
  added=$(git_q diff HEAD -U0 -- '*.nix' | grep -E '^\+[^+]' || true)
  if grep -qE 'stateVersion' <<<"$added"; then
    fail "a stateVersion line was changed; it must never change" "put the old stateVersion line back, then run nixctl apply again"
  fi
  if grep -iE '(password|passwd|secret|token|api_?key)[A-Za-z_]*[[:space:]]*=[[:space:]]*"[^"]+"' <<<"$added" |
    grep -viE '(file|path|dir)[[:space:]]*=' | grep -q .; then
    fail "a password, token or key looks like it was written into a .nix file" "remove it; secrets go in secrets/ with agenix (ask Riley)"
  fi
}

format_changed() {
  local files
  files=$( (git_q diff HEAD --name-only --diff-filter=AM; git_q ls-files --others --exclude-standard) | grep -E '\.nix$' | sort -u || true)
  [[ -n $files ]] || return 0
  # shellcheck disable=SC2086
  nix fmt -- $files >/dev/null 2>&1 || true
}

eval_drv() {
  nix eval --raw "$FLAKE_ATTR.config.system.build.toplevel.drvPath" >"$STATE/drv" 2>"$LOG"
}

cmd_check() {
  lock
  git_q add -A
  guards
  format_changed
  git_q add -A
  say "== evaluating the config"
  if ! eval_drv; then
    explain_nix_error "$LOG"
    fail "the config has an error" "$HINT"
  fi
  ok "the config evaluates (nothing built or changed yet)" "nixctl apply \"short description of the change\""
}

cmd_apply() {
  local msg=${1:-} new start
  [[ -n $msg ]] || fail "apply needs a message" "nixctl apply \"what you changed\""
  lock
  start=$SECONDS
  git_q add -A
  guards
  format_changed
  git_q add -A

  say "== 1/3 evaluate"
  if ! eval_drv; then
    explain_nix_error "$LOG"
    fail "the config has an error, nothing was changed" "$HINT"
  fi

  say "== 2/3 build (can take several minutes; wait for it)"
  if [[ $SIM == 1 ]]; then
    new="(simulated) $(cat "$STATE/drv")"
    say "(simulated) build of $(cat "$STATE/drv")"
  else
    if ! new=$(nix build --no-link --print-out-paths "$FLAKE_ATTR.config.system.build.toplevel" 2>"$LOG"); then
      explain_nix_error "$LOG"
      fail "the build failed, nothing was changed (full log: $LOG)" "read ERROR; if it names a file in this repo fix it, otherwise run nixctl undo and report ERROR"
    fi
    if [[ $new == "$(readlink -f /run/current-system)" ]]; then
      commit "$msg"
      ok "no change to the running system (files saved)" ""
    fi
    say "== what changes:"
    nix store diff-closures /run/current-system "$new" 2>/dev/null | head -25 || true
  fi

  say "== 3/3 test, health check, switch"
  if ! as_root apply-system "$new" | tee -a "$LOG"; then
    fail "the new system broke something and was rolled back; your file edits are still there" "read the log lines above, run nixctl logs UNIT for more, fix the module, then nixctl apply again (or nixctl undo)"
  fi
  commit "$msg"
  ok "applied in $((SECONDS - start))s: $msg" "if something looks wrong later: nixctl rollback"
}

cmd_undo() {
  lock
  if git_q diff HEAD --quiet && [[ -z $(git_q ls-files --others --exclude-standard) ]]; then
    ok "nothing to undo; files already match the last saved version"
  fi
  git_q stash push --include-untracked -q -m "nixctl undo $(date -Is)"
  ok "unsaved edits removed (kept in git stash; Riley can get them back with git stash pop)" "nixctl status"
}

cmd_rollback() {
  lock
  if ! as_root rollback; then
    fail "rollback failed" "run nixctl status and report the output"
  fi
  if git_q log -1 --format=%s | grep -q '^nixctl: '; then
    git_q revert --no-edit HEAD >/dev/null
    say "== files reverted to match (git revert of the last nixctl change)"
  fi
  ok "the computer is back on the previous version" "nixctl status"
}

cmd_status() {
  local gen
  say "== running system"
  if [[ $SIM == 1 ]]; then
    say "(simulated) generation 42, running"
  else
    gen=$(readlink /nix/var/nix/profiles/system || true)
    say "profile: ${gen:-unknown}"
    say "running: $(readlink -f /run/current-system)"
  fi
  say "== unsaved file edits"
  git_q status --short | head -20
  [[ -n $(git_q status --short) ]] || say "(none)"
  say "== broken services"
  local bad
  bad=$(bad_units)
  if [[ -n ${NIXCTL_SIMULATE_FAIL_UNIT:-} ]]; then bad=$NIXCTL_SIMULATE_FAIL_UNIT; fi
  say "${bad:-(none)}"
  say "== disk"
  df -h --output=target,size,avail,pcent /nix/store /boot 2>/dev/null | awk '!seen[$1]++' || true
  say "== last saved changes"
  git_q log -5 --format='%h %ar  %s'
  if [[ -n $bad ]]; then
    ok "status shown; some services are broken" "nixctl logs $(head -1 <<<"$bad")"
  fi
  ok "status shown"
}

cmd_logs() {
  local unit=${1:-}
  [[ -n $unit ]] || fail "logs needs a unit name" "nixctl status (to see broken services)"
  [[ $unit == *.* ]] || unit=$unit.service
  journalctl -u "$unit" -b --no-pager -n 60 -o short-iso 2>&1 || true
  ok "last 60 log lines for $unit this boot" "nixctl map (to find the module for $unit)"
}

module_option() { # modules/services/foo.nix -> my.services.foo
  local p=${1#modules/}
  p=${p%.nix}
  say "my.${p//\//.}"
}

cmd_map() {
  local f opt desc state n
  say "Control panel: $HOSTFILE (which modules are on)"
  say "Programs list: $PKGFILE"
  say ""
  printf '%-28s %-7s %s\n' "MODULE" "STATE" "WHAT IT DOES"
  while IFS= read -r f; do
    [[ $(basename "$f") == default.nix ]] && continue
    opt=$(module_option "$f")
    desc=$(head -1 "$f" | sed -E 's/^#[[:space:]]*//')
    if [[ $f == modules/core/* ]]; then
      state=always
    elif grep -qE "^[[:space:]]*${opt//./\\.}\.enable[[:space:]]*=[[:space:]]*true;" "$HOSTFILE"; then
      state=on
    else
      state=off
    fi
    f=${f#modules/}
    printf '%-28s %-7s %s\n' "${f%.nix}" "$state" "$desc"
  done < <(find modules -name '*.nix' | sort)
  n=$(pkg_lines | wc -l)
  say ""
  say "Programs installed by name: $n (see $PKGFILE)"
  ok "map shown" "edit a module file, or use nixctl enable/disable/pkg"
}

cmd_new() {
  local name=${1:-} desc=${2:-} file opt
  [[ $name =~ ^[a-z0-9-]+/[a-z0-9][a-z0-9-]*$ ]] || fail "name must look like GROUP/NAME, e.g. services/jellyfin" "nixctl new services/NAME \"what it does\""
  [[ $name != core/* ]] || fail "core modules are made by Claude, not with nixctl new" "pick another group, e.g. services/ or apps/"
  [[ -n $desc ]] || fail "new needs a one-line description" "nixctl new $name \"what it does\""
  file=modules/$name.nix
  [[ ! -e $file ]] || fail "$file already exists" "edit $file instead"
  opt=$(module_option "$file")
  mkdir -p "$(dirname "$file")"
  cat >"$file" <<EOF
# $desc
{ config, lib, pkgs, ... }:
let
  cfg = config.$opt;
in
{
  options.$opt.enable = lib.mkEnableOption "${desc%.}";

  config = lib.mkIf cfg.enable {
    # Put this module's settings here.
  };
}
EOF
  git_q add "$file"
  ok "created $file (off until enabled)" "edit the settings inside config = lib.mkIf cfg.enable { ... }, then nixctl enable $name, then nixctl apply \"add $name\""
}

enable_line_re() { # regex for the enable line of a module option
  say "^[[:space:]]*${1//./\\.}\.enable[[:space:]]*=[[:space:]]*(true|false);"
}

cmd_enable() {
  local name=${1:-} file opt tmp
  file=modules/$name.nix
  [[ -n $name && -f $file ]] || fail "no module $file" "nixctl map (to see module names)"
  [[ $name != core/* ]] || ok "$name is a core module; it is always on"
  opt=$(module_option "$file")
  if grep -qE "$(enable_line_re "$opt")" "$HOSTFILE"; then
    sed -i -E "s#^([[:space:]]*)${opt//./\\.}\.enable[[:space:]]*=[[:space:]]*false;#\1$opt.enable = true;#" "$HOSTFILE"
  else
    grep -q '^[[:space:]]*# nixctl: modules' "$HOSTFILE" || fail "$HOSTFILE has no '# nixctl: modules' marker line" "ask Claude to fix the control panel layout"
    tmp=$(mktemp)
    awk -v line="  $opt.enable = true;" '
      { print }
      /^[[:space:]]*# nixctl: modules/ { print line }
    ' "$HOSTFILE" >"$tmp" && cat "$tmp" >"$HOSTFILE" && rm -f "$tmp"
    sort_enable_block
  fi
  ok "$name is set to on (not applied yet)" "nixctl apply \"enable $name\""
}

cmd_disable() {
  local name=${1:-} file opt
  file=modules/$name.nix
  [[ -n $name && -f $file ]] || fail "no module $file" "nixctl map (to see module names)"
  [[ $name != core/* ]] || fail "$name is a core module and cannot be turned off" "nixctl map"
  opt=$(module_option "$file")
  sed -i -E "/$(enable_line_re "$opt")/d" "$HOSTFILE"
  ok "$name is set to off (not applied yet)" "nixctl apply \"disable $name\""
}

# Keeps the lines right under the marker sorted, so the control panel
# reads like a menu.
sort_enable_block() {
  local tmp
  tmp=$(mktemp)
  awk '
    function flush(   i, j, t) {
      for (i = 2; i <= n; i++) { t = buf[i]; j = i - 1; while (j >= 1 && buf[j] > t) { buf[j + 1] = buf[j]; j-- } buf[j + 1] = t }
      for (i = 1; i <= n; i++) if (i == 1 || buf[i] != buf[i - 1]) print buf[i]
      n = 0
    }
    inblock && /^[[:space:]]*my\.[A-Za-z0-9.-]+\.enable = true;[[:space:]]*$/ { buf[++n] = $0; next }
    inblock { flush(); inblock = 0 }
    /^[[:space:]]*# nixctl: modules/ { print; inblock = 1; next }
    { print }
    END { flush() }
  ' "$HOSTFILE" >"$tmp" && cat "$tmp" >"$HOSTFILE" && rm -f "$tmp"
}

pkg_lines() {
  awk '/environment\.systemPackages = with pkgs; \[/ {inl=1; next} inl && /^[[:space:]]*\];/ {inl=0} inl {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 != "") print}' "$PKGFILE"
}

write_pkgs() { # stdin: names
  local tmp
  tmp=$(mktemp)
  sort -fu >"$tmp.names"
  awk -v names="$tmp.names" '
    /environment\.systemPackages = with pkgs; \[/ { print; while ((getline n < names) > 0) print "    " n; skip=1; next }
    skip && /^[[:space:]]*\];/ { skip=0 }
    skip { next }
    { print }
  ' "$PKGFILE" >"$tmp" && cat "$tmp" >"$PKGFILE"
  rm -f "$tmp" "$tmp.names"
}

cmd_pkg() {
  local action=${1:-} name have
  shift || true
  [[ $action == add || $action == remove ]] || fail "use: nixctl pkg add NAME or nixctl pkg remove NAME"
  [[ $# -gt 0 ]] || fail "pkg $action needs a package name" "nixctl search WORD (to find the exact name)"
  have=$(pkg_lines)
  if grep -vqE '^[A-Za-z0-9_.+-]+$' <<<"$have"; then
    fail "$PKGFILE has a line that is not a plain package name" "move that line into a module (ask Claude), then try again"
  fi
  for name in "$@"; do
    [[ $name =~ ^[A-Za-z0-9_.+-]+$ ]] || fail "bad package name: $name"
    if [[ $action == add ]]; then
      if grep -qxF "$name" <<<"$have"; then say "== $name is already in the list"; continue; fi
      if ! nix eval --raw "$FLAKE_ATTR.pkgs.$name.name" >/dev/null 2>"$LOG"; then
        fail "there is no package called $name" "nixctl search $name"
      fi
      have=$(printf '%s\n%s\n' "$have" "$name")
      say "== added $name"
    else
      if ! grep -qxF "$name" <<<"$have"; then
        fail "$name is not in $PKGFILE (it may come from a module)" "nixctl map, then look for $name in the module files"
      fi
      have=$(grep -vxF "$name" <<<"$have" || true)
      say "== removed $name"
    fi
  done
  sed '/^$/d' <<<"$have" | write_pkgs
  git_q add "$PKGFILE"
  ok "programs list updated (not applied yet)" "nixctl apply \"$action $*\""
}

cmd_search() {
  local word=${1:-} src exact
  [[ -n $word ]] || fail "search needs a word" "nixctl search firefox"
  # Fast path: the word is already an exact package name (about 2 seconds).
  # shellcheck disable=SC2016
  if exact=$(nix eval --raw "$FLAKE_ATTR.pkgs.$word" --apply 'p: "${p.name}  ${p.meta.description or ""}"' 2>/dev/null); then
    say "exact match: $word  ($exact)"
    ok "$word is a package" "nixctl pkg add $word"
  fi
  src=$(nix eval --raw "$FLAKE_ATTR.pkgs.path" 2>"$LOG") || { explain_nix_error "$LOG"; fail "could not read nixpkgs"; }
  say "== no exact match; searching all packages for '$word' (first 15; the first search can take a few minutes)"
  NIXPKGS_ALLOW_UNFREE=1 nix search --impure --json "path:$src" "$word" 2>"$LOG" |
    jq -r 'to_entries | sort_by(.key | length) | .[:15][] | "\(.key | sub("^legacyPackages\\.[^.]+\\."; ""))  \(.value.version)  \(.value.description)"' || true
  ok "search done" "nixctl pkg add NAME (use the exact name from the first column)"
}

cmd_option() {
  local path=${1:-} expr
  [[ $path =~ ^[A-Za-z0-9_.\<\>*-]+$ ]] || fail "option needs a name like services.jellyfin.enable" "nixctl option services.jellyfin"
  expr=$(
    cat <<'EOF'
opts: let
  path = builtins.filter (s: builtins.isString s && s != "") (builtins.split "\\." "OPTPATH");
  isOpt = x: builtins.isAttrs x && (x._type or null) == "option";
  isDrv = x: builtins.isAttrs x && (x.type or null) == "derivation";
  take = n: l: if n == 0 || l == [] then [] else [ (builtins.head l) ] ++ take (n - 1) (builtins.tail l);
  san = d: v:
    if builtins.isFunction v then "<function>"
    else if isDrv v then "<package ${v.name or "?"}>"
    else if builtins.isPath v then toString v
    else if builtins.isAttrs v then (if d > 2 then "<set>" else builtins.mapAttrs (_: san (d + 1)) v)
    else if builtins.isList v then (if d > 2 then "<list>" else map (san (d + 1)) (take 20 v))
    else v;
  safe = v: let r = builtins.tryEval (let s = san 0 v; in builtins.deepSeq s s); in if r.success then r.value else "<not set>";
  text = v: if builtins.isAttrs v then (v.text or "") else toString v;
  walk = cur: rest:
    if rest == [] then cur
    else if isOpt cur then
      (let sub = builtins.tryEval (cur.type.getSubOptions [ ]); in
       if sub.success && sub.value != { } then
         walk sub.value (if builtins.elem (builtins.head rest) [ "<name>" "*" ] then builtins.tail rest else rest)
       else null)
    else if builtins.isAttrs cur && builtins.hasAttr (builtins.head rest) cur then walk cur.${builtins.head rest} (builtins.tail rest)
    else null;
  o = walk opts path;
  # Deepest part of the path that does exist, and close names inside it.
  prefixes = builtins.genList (i: take (builtins.length path - 1 - i) path) (builtins.length path);
  nearest = let hits = builtins.filter (p: p == [ ] || walk opts p != null) prefixes; in if hits == [ ] then [ ] else builtins.head hits;
  nearSet = if nearest == [ ] then opts else walk opts nearest;
  missing = builtins.elemAt path (builtins.length nearest);
  close = if isOpt nearSet || !(builtins.isAttrs nearSet) then [ ] else
    take 8 (builtins.filter (n: builtins.substring 0 3 n == builtins.substring 0 3 missing) (builtins.attrNames nearSet));
  join = l: builtins.concatStringsSep "." l;
in
  if o == null then { exists = false; nearest = join nearest; inherit close; }
  else if !(isOpt o) then { exists = true; kind = "group"; children = builtins.attrNames o; }
  else {
    exists = true;
    kind = "option";
    type = o.type.description or "unknown";
    description = text (o.description or "");
    default = if o ? defaultText then text o.defaultText else if o ? default then safe o.default else "<no default>";
    current = safe o.value;
    example = if o ? example then (if builtins.isAttrs o.example && o.example ? text then o.example.text else safe o.example) else null;
  }
EOF
  )
  expr=${expr//OPTPATH/$path}
  if ! nix eval --json "$FLAKE_ATTR.options" --apply "$expr" >"$STATE/option.json" 2>"$LOG"; then
    explain_nix_error "$LOG"
    fail "could not read options (the config may have an error)" "nixctl check"
  fi
  if [[ $(jq -r .exists "$STATE/option.json") != true ]]; then
    local near close
    near=$(jq -r .nearest "$STATE/option.json")
    close=$(jq -r '.close | join(", ")' "$STATE/option.json")
    [[ -z $close ]] || say "Did you mean one of these (inside ${near:-the top level}): $close"
    fail "option $path does not exist; do not use it" "nixctl option ${near:-services} (to list what exists there)"
  fi
  if [[ $(jq -r .kind "$STATE/option.json") == group ]]; then
    say "$path contains:"
    jq -r '.children | join("  ")' "$STATE/option.json" | fold -s -w 100
    ok "$path is a group of options" "nixctl option $path.NAME (pick one from the list)"
  fi
  jq -r '"name: '"$path"'\ntype: \(.type)\ndefault: \(.default | if type == "string" then . else tojson end)\ncurrent value: \(.current | tojson)\n" + (if .example then "example: \(.example | if type == "string" then . else tojson end)\n" else "" end) + "description: \(.description | .[0:600])"' "$STATE/option.json"
  ok "option $path exists" "set it inside a module's config block, then nixctl apply"
}

cmd_update() {
  local input=${1:-}
  lock
  if [[ -n $input ]]; then nix flake update "$input" 2>"$LOG" || { explain_nix_error "$LOG"; fail "update failed"; }
  else nix flake update 2>"$LOG" || { explain_nix_error "$LOG"; fail "update failed"; }; fi
  exec 8>&-
  NIXCTL_ALLOW_LOCK=1 exec "$0" apply "update ${input:-all inputs}"
}

cmd_clean() {
  local keep=${1:-5} before after
  lock
  before=$(df -h --output=avail /nix/store | tail -1 | tr -d ' ')
  if ! as_root clean "$keep"; then fail "cleanup failed" "nixctl status"; fi
  after=$(df -h --output=avail /nix/store | tail -1 | tr -d ' ')
  ok "kept the newest $keep system versions and deleted unused files; free space $before -> $after" ""
}

cmd_audit() {
  local facts n=0
  say "== reading settings (one evaluation)"
  if ! facts=$(nix eval --json "$FLAKE_ATTR.config" --apply '
    c: {
      gc = c.nix.gc.automatic;
      optimise = c.nix.optimise.automatic || (c.nix.settings.auto-optimise-store or false);
      bootLimit = c.boot.loader.systemd-boot.configurationLimit;
      systemdBoot = c.boot.loader.systemd-boot.enable;
      zram = c.zramSwap.enable;
      fstrim = c.services.fstrim.enable;
      docs = c.documentation.nixos.enable;
      journal = c.services.journald.extraConfig;
      waitOnline = c.systemd.services.NetworkManager-wait-online.enable or false;
      nm = c.networking.networkmanager.enable;
      jobs = c.nix.settings.max-jobs or "auto";
      minFree = c.nix.settings.min-free or null;
    }' 2>"$LOG"); then
    explain_nix_error "$LOG"
    fail "could not read the config" "nixctl check"
  fi
  finding() {
    n=$((n + 1))
    say "$n. [$1] $2"
    say "   FIX: $3"
  }
  [[ $(jq -r .gc <<<"$facts") == true ]] || finding disk "Old system versions are never deleted automatically." "in modules/core/nix.nix set: nix.gc = { automatic = true; dates = \"weekly\"; options = \"--delete-older-than 14d\"; };"
  [[ $(jq -r .optimise <<<"$facts") == true ]] || finding disk "Identical files in /nix/store are not merged." "in modules/core/nix.nix set: nix.optimise.automatic = true;"
  if [[ $(jq -r .systemdBoot <<<"$facts") == true && $(jq -r .bootLimit <<<"$facts") == null ]]; then
    finding disk "The boot menu keeps every version, so /boot can fill up." "in modules/core/boot.nix set: boot.loader.systemd-boot.configurationLimit = 10;"
  fi
  [[ $(jq -r .minFree <<<"$facts") != null ]] || finding disk "Nothing frees space when the disk gets nearly full." "in modules/core/nix.nix set: nix.settings.min-free = 5 * 1024 * 1024 * 1024;"
  grep -q SystemMaxUse <<<"$(jq -r .journal <<<"$facts")" || finding disk "System logs can grow to 4 GB." "in modules/core/system.nix set: services.journald.extraConfig = \"SystemMaxUse=500M\";"
  [[ $(jq -r .zram <<<"$facts") == true ]] || finding speed "No compressed RAM swap, so heavy jobs hit the disk sooner." "in modules/core/system.nix set: zramSwap.enable = true;"
  [[ $(jq -r .fstrim <<<"$facts") == true ]] || finding speed "SSD trim is off." "in modules/core/system.nix set: services.fstrim.enable = true;"
  if [[ $(jq -r .nm <<<"$facts") == true && $(jq -r .waitOnline <<<"$facts") == true ]]; then
    finding speed "Boot waits for the network to be fully online." "check first with: systemd-analyze blame | head; if NetworkManager-wait-online is near the top, set in modules/core/network.nix: systemd.services.NetworkManager-wait-online.enable = false; (skip if a service needs the network at boot)"
  fi
  [[ $(jq -r .docs <<<"$facts") == false ]] || finding rebuild "Every rebuild regenerates the NixOS options manual." "optional, saves rebuild time: in modules/core/nix.nix set documentation.nixos.enable = false; (removes man configuration.nix; nixctl option still works)"

  # Layout checks: text only, no evaluation.
  local f opt stray dupes
  while IFS= read -r f; do
    [[ $(basename "$f") == default.nix ]] && continue
    head -1 "$f" | grep -q '^#' || finding layout "$f has no one-line description on line 1." "add a comment like '# What this module does' as the first line"
    if [[ $f != modules/core/* ]]; then
      opt=$(module_option "$f")
      grep -qF "options.$opt" "$f" || finding layout "$f does not declare options.$opt.enable." "use the module shape from the skill (nixctl new makes it)"
    fi
  done < <(find modules -name '*.nix' | sort)
  stray=$(find . -maxdepth 1 -type f -name '*.nix' ! -name flake.nix | sed 's#^\./##' || true)
  [[ -z $stray ]] || finding layout "Loose .nix files at the top of the repo: $(tr '\n' ' ' <<<"$stray")" "move each into modules/GROUP/ (needs Claude)"
  # shellcheck disable=SC2016
  dupes=$(find modules hosts -name '*.nix' -print0 | xargs -0 awk '
    { gsub(/^[[:space:]]+/, ""); line[FNR] = $0 }
    FNR >= 3 && line[FNR] != "" && line[FNR-1] != "" && line[FNR-2] != "" && line[FNR] !~ /^[]})];?$/ {
      k = line[FNR-2] "\n" line[FNR-1] "\n" line[FNR]; if (!(k in seen)) seen[k] = FILENAME; c[k]++ }
    END { for (k in c) if (c[k] >= 3) { split(k, p, "\n"); printf "%dx in %s: %s\n", c[k], seen[k], p[1] } }' | sort -rn | head -3 || true)
  if [[ -n $dupes ]]; then
    while IFS= read -r f; do finding duplicate "The same 3 lines repeat $f" "fold the copies into one loop (lib.genAttrs or a list); needs Claude"; done <<<"$dupes"
  fi
  if [[ $SIM != 1 ]]; then
    say "== disk now"
    df -h --output=target,size,avail,pcent /nix/store /boot 2>/dev/null | awk '!seen[$1]++' || true
    say "system versions kept: $(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | wc -l)"
  fi
  if [[ $n -eq 0 ]]; then ok "no findings"; fi
  ok "$n findings" "do one FIX at a time and run nixctl apply after each; findings marked 'needs Claude' are for a bigger model"
}

cmd_help() {
  cat <<'EOF'
nixctl: change this NixOS computer safely. Run from anywhere.

Look:
  nixctl map                      every module, on/off, and what it does
  nixctl status                   running version, unsaved edits, broken services, disk
  nixctl search WORD              find a package name
  nixctl option NAME              check an option exists, its type, default, current value
  nixctl logs UNIT                last log lines of a service
Change files (nothing happens until apply):
  nixctl pkg add NAME...          add programs to hosts/HOST/packages.nix
  nixctl pkg remove NAME...       remove programs from that list
  nixctl new GROUP/NAME "what"    make a new module file (off until enabled)
  nixctl enable GROUP/NAME        turn a module on
  nixctl disable GROUP/NAME       turn a module off
Apply:
  nixctl check                    find config errors fast, change nothing
  nixctl apply "message"          build, test, keep only if healthy, save in git
  nixctl undo                     throw away unsaved edits (kept in git stash)
  nixctl rollback                 go back to the previous system version
Upkeep:
  nixctl update [INPUT]           update nixpkgs and other inputs, then apply
  nixctl clean [KEEP]             delete old system versions (keeps 5) and unused files
  nixctl audit                    list ways to save disk, speed up, and tidy the config
EOF
  ok "help shown" "nixctl map"
}

case ${1:-help} in
  map) cmd_map ;;
  status) cmd_status ;;
  search) cmd_search "${2:-}" ;;
  option) cmd_option "${2:-}" ;;
  logs) cmd_logs "${2:-}" ;;
  pkg) shift; cmd_pkg "$@" ;;
  new) cmd_new "${2:-}" "${3:-}" ;;
  enable) cmd_enable "${2:-}" ;;
  disable) cmd_disable "${2:-}" ;;
  check) cmd_check ;;
  apply) cmd_apply "${2:-}" ;;
  undo) cmd_undo ;;
  rollback) cmd_rollback ;;
  update) cmd_update "${2:-}" ;;
  clean) cmd_clean "${2:-5}" ;;
  audit) cmd_audit ;;
  version) ok "nixctl version $NIXCTL_VERSION" ;;
  help | -h | --help) cmd_help ;;
  *) say "unknown command: $1"; cmd_help ;;
esac
