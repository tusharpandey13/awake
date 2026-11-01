# awake

Keep a Mac from sleeping or locking, on demand, and put everything back afterwards.

While on, the Mac stays awake even with the lid closed, the screen does not lock, and the screen saver does not start. When it stops, by `awake off` or when the timer expires, the previous settings are restored. The display still turns off on its normal timer unless you pass `--display`.

macOS only. Needs an admin account for the lid-close part.

## Install

```sh
git clone https://github.com/tusharpandey13/awake.git
cd awake
make install
```

This symlinks `awake.sh` to `~/bin/awake`, so keep the clone. Use `make install BINDIR=/some/dir` for another location and `make uninstall` to remove the link.

## Usage

```sh
awake on            # 6 hours
awake on 2          # 2 hours
awake on 0          # until `awake off`
awake on --display  # keep the display on too
awake on --noroot   # no sudo; closing the lid sleeps as usual
awake status
awake off
awake setpw         # optional: store your login password in the keychain
```

`awake on` asks for sudo and for your login password. macOS only changes the screen-lock delay when given the login password; `awake setpw` saves retyping it. `awake --help` has the full manual, including edge cases.

| Flag | Effect |
|---|---|
| `--display` | Also keep the display on |
| `--noroot`, `--allowlidsleep` | Synonyms: don't run `sudo pmset -a disablesleep 1` |
| `--password PW` | Use this login password. It's visible in `ps` and shell history, so prefer `setpw` |

## Config

`~/.awake.conf` is created on first run with every setting commented out. It's sourced by bash, and flags win over it.

| Setting | Default | Effect |
|---|---|---|
| `hours` | `6` | Default duration for `awake on` (`0` = until `awake off`) |
| `display` | `0` | `1` keeps the display on, as `--display` |
| `disablesleep` | `1` | `0` skips `pmset`, as `--noroot` |
| `lock` | `1` | `0` leaves the screen lock alone; no login password needed |
| `saver` | `1` | `0` leaves the screen saver alone |

## How it works

| Concern | Mechanism | Restored by |
|---|---|---|
| Idle sleep | `caffeinate -i -s` | Ends with the supervisor |
| Lid-close sleep | `sudo pmset -a disablesleep 1` | A root guard process, when the supervisor exits |
| Screen lock | `sysadminctl -screenLock off` | The supervisor, using the password it holds in memory only |
| Screen saver | `defaults -currentHost write com.apple.screensaver idleTime -int 0` | The supervisor |

Previous values are saved in `~/.awake.*` while on, so the exact old state comes back, not a default. If `disablesleep` was already 1 before `on`, it stays 1 after `off`.

Sudo is only used while you're at the keyboard. The root guard started by `on` handles the restore, so a timer expiring unattended never waits on a password or Touch ID prompt.

## Caveats

- **Closing the lid doesn't sleep the Mac.** In a bag it drains the battery and runs hot. Use `--noroot` if you might carry it while on.
- **The Mac doesn't lock.** Anyone with physical access can use it, so don't leave it on unattended in public.
- **After a reboot or crash while on,** settings can stay changed. Run `awake off` to restore them.
- Critical battery and overheating can still force sleep.

## Tests

```sh
make test
```

The tests run against stubs for `sudo`, `pmset`, `sysadminctl`, `defaults`, `security` and `caffeinate` in a temporary `HOME`, so they don't change your settings or disturb a running `awake`.

## License

[MIT](LICENSE)
