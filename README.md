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
awake on            # until `awake off`
awake on 2          # 2 hours
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

### Skip the sudo prompt (optional)

`awake on` asks for sudo (Touch ID or password) to change `disablesleep`. To skip it, install a sudoers rule that allows only `pmset -a disablesleep 0` and `pmset -a disablesleep 1` without a password:

```sh
awake sudoers > /tmp/awake.sudoers &&
sudo visudo -cf /tmp/awake.sudoers &&
sudo install -m 440 -o root -g wheel /tmp/awake.sudoers /etc/sudoers.d/awake
```

Any process running as you can then toggle `disablesleep`, for example to keep the Mac awake with the lid shut, but nothing else: no root shell and no other `pmset` settings. Remove it with `sudo rm /etc/sudoers.d/awake`.

## Config

`~/.awake.conf` is created on first run with every setting commented out. It's sourced by bash, and flags win over it.

| Setting | Default | Effect |
|---|---|---|
| `hours` | `0` | Default duration for `awake on` (`0` = until `awake off`) |
| `display` | `0` | `1` keeps the display on, as `--display` |
| `disablesleep` | `1` | `0` skips `pmset`, as `--noroot` |
| `lock` | `1` | `0` leaves the screen lock alone; no login password needed |
| `saver` | `1` | `0` leaves the screen saver alone |
| `dimlid` | `1` | `0` leaves brightness alone; `1` sets the built-in display to 0 when the lid closes and 50% when it opens |

## How it works

| Concern | Mechanism | Restored by |
|---|---|---|
| Idle sleep | `caffeinate -i -s`, restarted by the supervisor if something else kills it | Ends with the supervisor |
| Lid-close sleep | `sudo pmset -a disablesleep 1` | A guard process, when the supervisor exits |
| Screen lock | `sysadminctl -screenLock off` | The supervisor, using the password it holds in memory only |
| Screen saver | `defaults -currentHost write com.apple.screensaver idleTime -int 0` | The supervisor |
| Backlight with lid closed | The supervisor polls `ioreg` for the lid every 2s and sets brightness through `brightness.swift` (private DisplayServices API), built to `~/.awake.bright` with `swiftc` on first use | Set to 50% if awake ends with the lid closed |

Previous values are saved in `~/.awake.*` while on, so the exact old state comes back, not a default. If `disablesleep` was already 1 before `on`, it stays 1 after `off`.

A timer expiring unattended never waits on a password or Touch ID prompt. With the sudoers rule, the guard runs as you and calls `sudo -n pmset` at the end. Without it, `on` asks for sudo while you're there and starts the guard as root.

## Caveats

- **Closing the lid doesn't sleep the Mac.** In a bag it drains the battery and runs hot. Use `--noroot` if you might carry it while on.
- **The Mac doesn't lock.** Anyone with physical access can use it, so don't leave it on unattended in public.
- **After a reboot or crash while on,** settings can stay changed. Run `awake off` to restore them.
- Lid dimming needs `swiftc` (Xcode Command Line Tools) once. Without it, dimming is skipped and logged in `~/.awake.log`. On lid open the level is a fixed 50%, not what it was before.
- Critical battery and overheating can still force sleep.

## Tests

```sh
make test
```

The tests run against stubs for `sudo`, `pmset`, `sysadminctl`, `defaults`, `security` and `caffeinate` in a temporary `HOME`, so they don't change your settings or disturb a running `awake`.

## License

[MIT](LICENSE)
