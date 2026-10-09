# Fort Galgs

Reserve a few of a Linux machine's fastest CPU cores for the apps you care
about — a game, a video call — and fence everything else off them, so a CI
run in a VM, a container build, or a test sweep in tmux cannot starve them.

One window: a live map of the chip, with the reserved cores inside a log
stockade; a switch beside each running app to move it into or out of the fort;
and one button to raise the fort or stand down. Mountain men stand watch on
the walls while it is up.

Requires systemd with cgroup v2. Arch Linux is the packaged target.

| File | Installed to | Does |
|------|--------------|------|
| `fort-galgs` | `/usr/bin` | GTK front end |
| `fortctl` | `/usr/bin` | Backend: `status [--json]`, `on`, `off`, `protect`/`unprotect <app>...`, `adopt <pid>`, `watch`; root half via `--system on\|off` |
| `fort-galgs.toml` | `/etc` | How many cores to reserve, and which apps always live in the fort |
| `sudoers.in` | `/etc/sudoers.d/fort-galgs` | Lets the `fort-galgs` group run exactly `fortctl --system on` and `… off` |
| `sysusers.conf` | `/usr/lib/sysusers.d/fort-galgs.conf` | Creates that group |
| `systemd/fort-galgs-cpuset.conf` | `/usr/lib/systemd/system/user@.service.d/` | Delegates the cpuset controller to user sessions |
| `systemd/fort-galgs-watch.service` | `/usr/lib/systemd/user/` | Pulls configured apps in as they start, while the fort is up |

## Configuring

`/etc/fort-galgs.toml`:

```toml
reserve_cores = 4      # physical cores; each brings its SMT sibling
protect = ["steam"]    # process names, as in /proc/<pid>/comm
```

Both the user and root halves read it, so a change applies the next time the
fort is raised.

## What "on" does

The reserved CPUs are the `reserve_cores` cores with the highest
`cpuinfo_max_freq`, plus their SMT siblings. Those are the cores the
scheduler prefers (Turbo Boost Max, preferred cores, P-cores on hybrid
parts), so without a fence background work lands on them first. Ties go by
core id, with CPU 0's core last, since it takes the most interrupts.

1. Every scope holding a process named in `protect` moves into `fort.slice`
   in the user's systemd manager, which gets `CPUWeight=1000`. `fort.slice` is
   never fenced: apps inside keep every CPU and have the reserved ones to
   themselves. `fort-galgs-watch.service` starts and keeps pulling such apps
   in as they launch.
2. `app.slice` and `background.slice` (terminals, tmux, tests, sandboxes) get
   `AllowedCPUs=` the other CPUs.
3. As root: `machine.slice` (VMs) and `system.slice` (docker, services) get
   the same.

Every change is `--runtime`, so a reboot takes the fort down. `off` reverses
steps 2 and 3, resets the weight and stops the watcher. Apps stay in
`fort.slice`, where they do no harm.

Only scopes move, never services: pulling a service's processes out from
under it would break the service.

**Step 2 needs cpuset delegated** to `user@.service`, which systemd does not
do by default. The package's drop-in does it, but a running user manager only
sees it after `systemctl --user daemon-reexec` (a logout does not restart the
manager of a user who lingers). Until then step 2 is skipped, and the window
and `status` say so.

## Protecting an app by hand

In the window, flip the switch beside it. From a shell:

```bash
fortctl protect firefox     # every scope holding a process named firefox
fortctl unprotect firefox
fortctl protect app-gnome-firefox-2435960.scope   # one scope, exactly
```

It helps only while the fort is up, and lasts until the app quits or the
machine reboots. Apps in the `protect` list cannot be moved out: the watcher
would only pull them back.

## Installing

```bash
cd packaging/arch
makepkg -si
# or, building from a local checkout:
FORT_GALGS_GIT=git+file://$HOME/src/fort-galgs makepkg -si
```

Then, once per desktop user:

```bash
sudo gpasswd -a "$USER" fort-galgs
systemctl --user daemon-reexec
```

Without a package, `sudo make install` installs the same files under `/usr`.

## Checking it after a change

```bash
make check
./fort-galgs --self-test              # builds every page, draws every state
./fort-galgs --snapshot /tmp/fort.png  # the fort, down and up, from live load
./fortctl status
```
