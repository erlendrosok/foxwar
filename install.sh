#!/usr/bin/env bash
# foxwar installer.
#
#   ./install.sh              install foxwar to ~/.local/bin
#   ./install.sh --service    also install + enable the foxwar-poll systemd
#                             user service (keeps casualty rates warm)
#
# Everything lands under $HOME; no root needed.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"

echo "installing foxwar"
mkdir -p "$bin_dir"
install -m 755 "$src/foxwar" "$bin_dir/foxwar"
echo "  $bin_dir/foxwar"

case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "  note: $bin_dir is not on your PATH" ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
    echo "  warning: python3 not found (foxwar needs Python 3.7+)"
fi

if [ "${1:-}" = "--service" ]; then
    unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$unit_dir"
    install -m 644 "$src/foxwar-poll.service" "$unit_dir/foxwar-poll.service"
    echo "  $unit_dir/foxwar-poll.service"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload
        systemctl --user enable --now foxwar-poll.service
        echo "  service enabled and started"
    else
        echo "  systemctl not found - enable it yourself later"
    fi
fi

echo "done - try:  foxwar"
