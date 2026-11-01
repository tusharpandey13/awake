#!/bin/bash
# Exercises awake against stubs in a throwaway HOME; never touches real pmset/sudo/sysadminctl/defaults.
REPO=$(cd "$(dirname "$0")/.." && pwd)
A=$REPO/awake.sh
T=$(mktemp -d); export HOME=$T/home; S=$T/stub; mkdir -p "$HOME" "$S"; export ST=$T/state; mkdir -p "$ST"
trap 'pkill -f "$T" 2>/dev/null; rm -rf "$T"' EXIT
echo 0 > "$ST/sd"; echo "screenLock delay is 300 seconds" > "$ST/lock"
cat > "$S/pmset" <<'E'
#!/bin/bash
case "$*" in
  "-g batt") echo "Now drawing from 'AC Power'" ;;
  "-g") printf ' SleepDisabled\t\t%s\n' "$(cat "$ST/sd")" ;;
  "-a disablesleep "*) [ "$ROOT" = 1 ] || { echo "pmset: not root" >&2; exit 1; }; echo "$3" > "$ST/sd" ;;
  "-g assertions") ;;
esac
E
cat > "$S/sudo" <<'E'
#!/bin/bash
echo "sudo $*" >> "$ST/sudo.log"
[ -f "$ST/sudofail" ] && exit 1
bg=
while :; do case "$1" in -v) exit 0 ;; -n) shift ;; -b) bg=1; shift ;; *) break ;; esac; done
export ROOT=1
if [ -n "$bg" ]; then "$@" & exit 0; else exec "$@"; fi
E
cat > "$S/sysadminctl" <<'E'
#!/bin/bash
case "$2" in status) cat "$ST/lock" ;; off) echo "screenLock is off" > "$ST/lock" ;; *) echo "screenLock delay is $2 seconds" > "$ST/lock" ;; esac
E
cat > "$S/defaults" <<'E'
#!/bin/bash
case "$3" in read) cat "$ST/ss" 2>/dev/null || exit 1 ;; write) echo "$7" > "$ST/ss" ;; delete) rm -f "$ST/ss" ;; esac
E
printf '#!/bin/bash\nexit 1\n' > "$S/security"
printf '#!/bin/bash\necho "caffeinate $*" >> "$ST/caf.log"\nexec /bin/sleep 300\n' > "$S/caffeinate"
chmod +x "$S"/*; export PATH=$S:$PATH

pass=0; fail=0
ok() { if eval "$2"; then echo "ok   $1"; pass=$((pass+1)); else echo "FAIL $1 [$2]"; fail=$((fail+1)); fi; }
sd() { cat "$ST/sd"; }
waitgone() { for _ in {1..20}; do [ -f "$HOME/.awake.disablesleep" ] || return 0; sleep .5; done; }
reset() { "$A" off --password pw >/dev/null 2>&1; rm -f "$ST/sudo.log" "$ST/sudofail" "$HOME/.awake.conf" "$ST/caf.log"; echo "${1:-0}" > "$ST/sd"; }

"$A" status >/dev/null
ok "config created, all commented" '[ -f $HOME/.awake.conf ] && ! grep -qE "^[a-z]" $HOME/.awake.conf'

"$A" on 1 --password pw >/dev/null
ok "default: disablesleep set"     '[ "$(sd)" = 1 ]'
ok "default: state saved 0"        '[ "$(cat $HOME/.awake.disablesleep)" = 0 ]'
ok "default: lock off"             'grep -q off $ST/lock'
ok "awake.sh run directly: seen as on" '"$A" status | grep -q "awake: ON"'
ok "status shows SleepDisabled"    '"$A" status | grep -q "SleepDisabled: 1 (saved: 0)"'
ok "second on: already on"         '"$A" on 1 --password pw | grep -q "already on"'
"$A" off >/dev/null
ok "off: restored 0"               '[ "$(sd)" = 0 ]'
ok "off: state gone"               '[ ! -f $HOME/.awake.disablesleep ] && [ ! -f $HOME/.awake.pid ]'
ok "off: lock restored"            'grep -q "300 seconds" $ST/lock'

for f in --noroot --allowlidsleep; do
  reset; "$A" on 1 $f --password pw >/dev/null
  ok "$f: no sudo at all"          '[ ! -f $ST/sudo.log ]'
  ok "$f: disablesleep untouched"  '[ "$(sd)" = 0 ] && [ ! -f $HOME/.awake.disablesleep ]'
  ok "$f: lock still off"          'grep -q off $ST/lock'
  "$A" off >/dev/null
done

reset; "$A" on 1 --password pw >/dev/null; pid=$(cat "$HOME/.awake.pid")
pkill -P "$pid"; waitgone    # timer expiry: caffeinate ends, supervisor exits, nobody at the keyboard
ok "timer expiry: guard restored"  '[ "$(sd)" = 0 ] && [ ! -f $HOME/.awake.disablesleep ]'
ok "timer expiry: lock restored"   'grep -q "300 seconds" $ST/lock'

reset; "$A" on 1 --password pw >/dev/null; pid=$(cat "$HOME/.awake.pid"); kids=$(pgrep -P "$pid")
kill -9 "$pid"; kill $kids; waitgone
ok "supervisor SIGKILL: guard restored" '[ "$(sd)" = 0 ]'
ok "supervisor SIGKILL: lock left for off" '[ -f $HOME/.awake.lockdelay ]'

reset 1; "$A" on 1 --password pw >/dev/null; "$A" off >/dev/null
ok "prior value 1 preserved"       '[ "$(sd)" = 1 ]'

reset; touch "$ST/sudofail"; "$A" on 1 --password pw >/dev/null 2>&1; rc=$?
ok "sudo fail: exit 1"             '[ $rc = 1 ]'
ok "sudo fail: nothing changed"    'grep -q "300 seconds" $ST/lock && [ ! -f $HOME/.awake.ssidle ] && [ ! -f $HOME/.awake.lockdelay ] && [ ! -f $HOME/.awake.pid ]'

reset; echo 1 > "$ST/sd"; echo 0 > "$HOME/.awake.disablesleep"
"$A" off >/dev/null              # reboot: stale state, no guard
ok "stale state: off restores"     '[ "$(sd)" = 0 ] && [ ! -f $HOME/.awake.disablesleep ]'

reset; echo "disablesleep=0" > "$HOME/.awake.conf"; "$A" on 1 --password pw >/dev/null
ok "config disablesleep=0"         '[ ! -f $ST/sudo.log ] && [ "$(sd)" = 0 ]'
"$A" off >/dev/null

reset; printf 'hours=3\ndisplay=1\nlock=0\nsaver=0\n' > "$HOME/.awake.conf"; rm -f "$ST/ss"
"$A" on --noroot </dev/null >/dev/null; sleep 1
ok "config lock=0: no pw, untouched" 'grep -q "300 seconds" $ST/lock && [ ! -f $HOME/.awake.lockdelay ]'
ok "config saver=0: untouched"     '[ ! -f $ST/ss ] && [ ! -f $HOME/.awake.ssidle ]'
ok "config hours/display applied"  'grep -q -- "-d -t 10800" $ST/caf.log'
"$A" off >/dev/null

reset; echo "hours=3" > "$HOME/.awake.conf"; "$A" on 2 --noroot --password pw >/dev/null; sleep 1
ok "flag HOURS beats config"       'grep -q -- "-t 7200" $ST/caf.log'
"$A" off >/dev/null

reset; make -s -C "$REPO" install BINDIR="$T/bin" >/dev/null
ok "make install: symlink"         '[ -L $T/bin/awake ]'
"$T/bin/awake" on 1 --password pw >/dev/null
ok "installed name: seen as on"    '"$T/bin/awake" status | grep -q "awake: ON"'
"$T/bin/awake" off >/dev/null
make -s -C "$REPO" uninstall BINDIR="$T/bin"
ok "make uninstall: removed"       '[ ! -e $T/bin/awake ]'

echo "--- pass=$pass fail=$fail"
exit $fail
