#!/bin/bash
# Install Game Mode.
#
#   sudo bash install.sh
#
# Idempotent: run it again after editing anything here. It installs the
# launcher and its backend, the dash entry and icon, the sudoers rule for the
# backend's root half, and the systemd drop-in that delegates cpuset to user
# sessions.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BINDIR=/usr/local/bin
APPDIR=/usr/local/share/applications
ICONDIR=/usr/local/share/icons/hicolor/scalable/apps
SUDOERS=/etc/sudoers.d/game-mode
DELEGATE=/etc/systemd/system/user@.service.d/game-mode-cpuset.conf

if [[ $EUID -ne 0 ]]; then
    echo "install.sh must run as root: sudo bash install.sh" >&2
    exit 1
fi
USER_NAME="${SUDO_USER:?run this through sudo, so it knows whose rule to write}"

echo "installing game-mode and game-mode-cpus into $BINDIR"
# root-owned and not writable by the user: the sudoers rule below runs
# game-mode-cpus as root, so a user-editable copy would be a root shell.
install -o root -g root -Dm755 "$HERE/game-mode"       "$BINDIR/game-mode"
install -o root -g root -Dm755 "$HERE/game-mode-cpus"  "$BINDIR/game-mode-cpus"

echo "installing dash entry and icon"
install -Dm644 "$HERE/game-mode.desktop"  "$APPDIR/game-mode.desktop"
install -Dm644 "$HERE/game-mode.svg"      "$ICONDIR/game-mode.svg"
update-desktop-database "$APPDIR" || true
gtk-update-icon-cache -qtf /usr/local/share/icons/hicolor 2>/dev/null || true

# --- sudoers: exactly two argument vectors --------------------------------

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat >"$tmp" <<EOF
# Managed by Game Mode's install.sh -- edit there.
#
# Lets $USER_NAME fence system services and VMs off the game's CPUs without a
# password; the launcher runs sudo -n and has nowhere to show a prompt.
# sudoers matches the whole command line, so nothing else after the path is
# allowed.
Cmnd_Alias GAME_MODE = $BINDIR/game-mode-cpus --system on, \\
                       $BINDIR/game-mode-cpus --system off

$USER_NAME ALL=(root) NOPASSWD: GAME_MODE
EOF
if ! visudo -cqf "$tmp"; then
    echo "generated sudoers file is invalid, refusing to install it" >&2
    visudo -cf "$tmp" >&2 || true
    exit 1
fi
install -Dm440 "$tmp" "$SUDOERS"
echo "installed $SUDOERS (checked with visudo):"
sed 's/^/    /' "$SUDOERS"

# --- cpuset delegation ----------------------------------------------------

# systemd delegates cpu, memory and pids to user@.service by default, so a
# user's own AllowedCPUs= is silently ignored. Takes effect at next login.
mkdir -p "$(dirname "$DELEGATE")"
cat >"$DELEGATE" <<'EOF'
# Managed by Game Mode's install.sh -- edit there.
# Lets Game Mode fence the user's own apps off the game's CPUs.
[Service]
Delegate=cpu cpuset memory pids
EOF
systemctl daemon-reload
echo "installed $DELEGATE"

echo
uid="$(id -u "$USER_NAME")"
apps="/sys/fs/cgroup/user.slice/user-$uid.slice/user@$uid.service/app.slice"
if grep -qsw cpuset "$apps/cgroup.controllers"; then
    echo "installed. cpuset is already delegated to your session."
else
    echo "installed. Log out and back in once so your own apps can be fenced"
    echo "too; VMs and services are fenced from now on."
fi
