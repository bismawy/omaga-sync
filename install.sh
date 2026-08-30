#!/usr/bin/env bash
# Omaga Sync installer — copies plugin + services into user config.
# Usage: ./install.sh [--plugin-only]
set -euo pipefail

PLUGIN_ID="bisma.omaga-sync"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BIN_DST="$HOME/.local/bin/omaga-sync"
UNIT_DST="$HOME/.config/systemd/user"

plugin_only=0
[[ "${1:-}" == "--plugin-only" ]] && plugin_only=1

mkdir -p "$PLUGIN_DST" "$HOME/.local/bin" "$UNIT_DST" "$HOME/.local/state/omaga-sync" \
  "$HOME/.local/share/nautilus-python/extensions" \
  "$HOME/.local/share/icons/hicolor/scalable/emblems"

# The plugin loader rejects symlinks, so always copy.
install -m 644 "$SRC_DIR/manifest.json" "$PLUGIN_DST/manifest.json"
install -m 644 "$SRC_DIR/Panel.qml" "$PLUGIN_DST/Panel.qml"
install -m 644 "$SRC_DIR/I18n.js" "$PLUGIN_DST/I18n.js"
install -m 644 "$SRC_DIR/MaterialIcon.qml" "$PLUGIN_DST/MaterialIcon.qml"
install -m 644 "$SRC_DIR/IconButton.qml" "$PLUGIN_DST/IconButton.qml"
rm -f "$PLUGIN_DST/CloudIcon.qml"
mkdir -p "$PLUGIN_DST/icons"
install -m 644 "$SRC_DIR"/icons/*.svg "$PLUGIN_DST/icons/"

if [[ $plugin_only -eq 1 ]]; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  echo "Plugin disalin (hot-reload aktif)."
  exit 0
fi

if ! command -v mega-cmd-server >/dev/null 2>&1; then
  echo "PERINGATAN: mega-cmd-server tidak ditemukan." >&2
  echo "  Instal dulu: omarchy pkg aur add megacmd" >&2
fi

install -m 755 "$SRC_DIR/omaga-sync" "$BIN_DST"
install -m 755 "$SRC_DIR/omaga-login" "$HOME/.local/bin/omaga-login"
install -m 644 "$SRC_DIR/omaga-sync-engine.service" "$UNIT_DST/"
install -m 644 "$SRC_DIR/omaga-sync-monitor.service" "$UNIT_DST/"

# Nautilus emblems (GNOME Files sync-status badges).
if command -v nautilus >/dev/null 2>&1 && python3 -c "import gi; gi.require_version('Nautilus','4.1')" >/dev/null 2>&1; then
  install -m 644 "$SRC_DIR/nautilus/omaga-sync-emblems.py" \
    "$HOME/.local/share/nautilus-python/extensions/omaga-sync-emblems.py"
  install -m 644 "$SRC_DIR"/nautilus/icons/*.svg \
    "$HOME/.local/share/icons/hicolor/scalable/emblems/"
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  nautilus -q >/dev/null 2>&1 || true
fi

# Any mega-* call may have auto-spawned an unsupervised server; it would
# keep the socket so the systemd unit can never bind. Kill it first.
pkill -u "$USER" -x mega-cmd-server >/dev/null 2>&1 || true
sleep 1

systemctl --user daemon-reload
systemctl --user enable --now omaga-sync-engine.service
systemctl --user enable --now omaga-sync-monitor.service

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 \
  || echo "Aktifkan widget manual: omarchy plugin enable $PLUGIN_ID"

sleep 2
if "$BIN_DST" status >/dev/null 2>&1; then
  echo "Terpasang. Status: $("$BIN_DST" status)"
else
  echo "Terpasang; monitor sedang menyala, status file menyusul."
fi

if systemctl --user is-active --quiet omaga-sync-engine.service && ! mega-whoami >/dev/null 2>&1; then
  cat <<'EOF'

Langkah berikutnya (sekali saja, di terminal — termasuk prompt 2FA):
  1. mega-login email-anda
  2. mega-sync ~/Sync /Sync     # daftakan folder yang mau disinkron
Panel di bar akan ikut berubah otomatis dalam beberapa detik.
EOF
fi
