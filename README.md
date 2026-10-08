# Game Mode: CPU reservation on this machine

One icon in the GNOME dash on this machine. While it is on, nothing but the game may
run on the machine's two fastest cores, so a CI run in a VM,
a busy Kubernetes worker, or a test sweep in tmux cannot starve Rocket League.

| File | Installed to | Does |
|------|--------------|------|
| `game-mode` | `/usr/local/bin` | GTK front end: live per-thread CPU map, who is using the CPUs, one toggle |
| `game-mode-cpus` | `/usr/local/bin` | Backend: `status [--json]`, `on`, `off`; root half via `--system on\|off` |
| `game-mode.desktop`, `game-mode.svg` | `/usr/local/share/...` | Dash entry and icon |
| — | `/etc/sudoers.d/game-mode` | Lets the user run exactly `game-mode-cpus --system on` and `… off` |
| — | `/etc/systemd/system/user@.service.d/game-mode-cpuset.conf` | Delegates the cpuset controller to user sessions |

The look is in Rocket
League orange and blue.

## What "on" does

The reserved CPUs are the `RESERVE_CORES` (2) cores with the highest
`cpuinfo_max_freq`, plus their SMT siblings. On an i9-7900X that is cores 3
and 4, CPUs 3, 4, 13 and 14. Those are the Turbo Boost Max cores, which the
scheduler prefers, so without a fence background work lands on them first.

1. Steam's scope, with every game it launched, moves into `game.slice` in the
   user's systemd manager, which gets `CPUWeight=1000`. `game.slice` is never
   fenced: the game keeps every CPU and has four that nothing else may use.
2. `app.slice` and `background.slice` (terminals, tmux, tests, sandboxes) get
   `AllowedCPUs=` the other CPUs.
3. As root: `machine.slice` (VMs) and `system.slice` (docker, services) get
   the same.

Every change is `--runtime`, so a reboot turns Game Mode off. `off` reverses
steps 2 and 3 and resets the weight. Steam stays in `game.slice`, where it
does no harm.

Two cases need attention:

- **Step 2 needs cpuset delegated** to `user@.service`. systemd does not do
  that by default, and the drop-in only applies at the next login. Until
  then, step 2 is skipped, and the window and `status` say so.
- **A Steam started after "on"** lands in the fenced `app.slice`. The window
  shows a banner for this, and running `on` again pulls Steam in.

## Installing

```bash
cd game-mode
sudo bash install.sh
```

Then log out and back in once, and pin it to the dash:

```bash
gsettings get org.gnome.shell favorite-apps   # read first: set replaces the list
```

## Checking it after a change

```bash
python3 ~/.claude/scripts/python-check.py --imports game-mode game-mode-cpus
shellcheck install.sh
desktop-file-validate game-mode.desktop
./game-mode --self-test             # builds every page, draws every state
./game-mode --snapshot /tmp/chip.png  # the chip, off and on, from live load
./game-mode-cpus status
```
