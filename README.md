# ⚡ Omaga Sync

**Lightweight MEGA two-way sync bar widget, monitor daemon, and GNOME Files / Nautilus emblem integrator for [Omarchy](https://github.com/basecamp/omarchy) (Quickshell / Wayland / Hyprland).**

Powered directly by the headless [`mega-cmd-server`](https://github.com/meganz/MEGAcmd) engine—designed as a reliable, glitch-free Wayland alternative to the official MEGAsync desktop app.

[![Platform: Omarchy](https://img.shields.io/badge/Platform-Omarchy%20%2F%20Quickshell-ff5555.svg)](https://github.com/basecamp/omarchy)
[![Engine: MEGAcmd](https://img.shields.io/badge/Engine-MEGAcmd%20Server-d9272e.svg)](https://github.com/meganz/MEGAcmd)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Version: 1.1.3](https://img.shields.io/badge/Version-1.1.3-teal.svg)](./manifest.json)

[English](README.md) | [Bahasa Indonesia](README_ID.md)

---

<p align="center">
  <img src="preview.webp" alt="Omaga Sync Preview" width="720" />
</p>

---

## ⚡ Architecture

```text
mega-cmd-server ── systemd (omaga-sync-engine.service)     Headless MEGAcmd sync daemon
      │ Local UNIX socket
omaga-sync monitor ── systemd (omaga-sync-monitor.service) 5s poll → status.json (bounded reader)
      ├── GNOME Files / Nautilus Integrator                └─ In-process Gio metadata::emblems
      └── Desktop Notification Dispatcher                  └─ notify-send on errors/issues
Bar Widget (bisma.omaga-sync) ── Quickshell QML Panel      ├─ Storage quota, transfer progress
                                                           ├─ Pause / Resume / Add / Remove pairs
                                                           └─ Interactive cloud folder picker & creator
```

---

## 🚀 Key Features

- 📊 **Dynamic Status Bar Indicator:**
  - Real-time synced status icon, smooth pulse animation while actively transferring, dimmed icon when paused, and high-visibility alert state during sync issues or offline engine.
- 📂 **Rich Interactive Panel:**
  - Account storage quota progress bar (used vs. total quota).
  - List of local ↔ remote folder pairs with individual sync status.
  - Global & per-folder **Pause / Resume** controls.
  - **Remove Sync** button (safe; files on both local and cloud stay intact).
  - **Interactive Remote Folder Picker & Creator**: browse and select existing remote MEGA folders or create new cloud directories straight from the UI.
  - Integrated session management with **Logout** and terminal-assisted **Login** onboarding.
  - Account address is masked by default and revealed with the **eye button** next to it; the choice is remembered.
  - **Logs tab**: a live list of MEGA sync issues, each row copyable on its own and all at once, with a checkmark confirming the copy. This is the first place to look when a notification says a sync failed.
- 🏷️ **Nautilus / GNOME Files Sync Emblems:**
  - Corner status badges on synced folders and files via `metadata::emblems` (`emblem-omaga-synced`, `emblem-omaga-syncing`, `emblem-omaga-error`, and `emblem-omaga-transfer`).
  - High-performance in-process `Gio` integration with diffed writes, rate-budget chunking, and automatic cleanup on monitor stop/uninstall.
- 🌐 **Bilingual Internationalization (i18n):**
  - Full English (`en`) and Bahasa Indonesia (`id`) support with automatic system locale detection or configurable widget preference.
- 🔔 **Actionable & Spam-Free Notifications:**
  - Sent only when user intervention is required (login expired, engine offline, or sync issue encountered).
- 🛡️ **Systemd Supervision & Auto-Healing:**
  - Supervises `mega-cmd-server` under systemd user session with automatic startup repair for unmanaged instances.

---

## 📦 Installation & Setup

### 1. Prerequisite: Install MEGAcmd
```bash
omarchy pkg aur add megacmd
```

### 2. Install the Plugin
Add the plugin through Omarchy so it stays updatable:
```bash
omarchy plugin add https://github.com/bismawy/omaga-sync --enable
```

### 3. Install the Engine & Services
```bash
git clone https://github.com/bismawy/omaga-sync.git
cd omaga-sync
./install.sh
```
The installer provisions the `omaga-sync` engine, the two systemd units, and the Nautilus emblems. It also copies the panel files, so running it alone works too — but the plugin is then **not** git-managed and `omarchy plugin update` will refuse it (`not a git checkout`).

Updating later:
```bash
omarchy plugin update bisma.omaga-sync
```

### 4. Log in to MEGA (One-time)
```bash
mega-login your-email@example.com
```
*(Or click the **Login** button directly from the Omaga Sync bar panel to open the interactive login helper).*

---

## 🛠️ CLI Commands (`omaga-sync`)

The `omaga-sync` utility can be executed directly from terminal or custom scripts:

| Command | Description |
|---|---|
| `omaga-sync status` | Print current bounded status JSON from the monitor daemon |
| `omaga-sync pause [folder]` | Pause syncing for a specific folder or all active pairs |
| `omaga-sync resume [folder]` | Resume syncing for a specific folder or all active pairs |
| `omaga-sync add <mega-folder> [base]` | Pair remote MEGA folder to a local directory (default `~/MEGA`) |
| `omaga-sync remove <local-folder>` | Remove sync pair safely (keeps files intact on disk & cloud) |
| `omaga-sync logout` | Log out of active MEGA session |
| `omaga-sync login [email]` | Launch interactive terminal login helper |
| `omaga-sync open <folder>` | Open local folder in default file manager (`xdg-open`) |
| `omaga-sync repair` | Terminate unmanaged server instances and restart via systemd |

---

## 🔧 Development & Hot Reload

To refresh the panel after editing a QML / JS file, copy just that file and reload plugins:
```bash
install -m 644 Panel.qml ~/.config/omarchy/plugins/bisma.omaga-sync/
omarchy-shell shell rescanPlugins
```
If a broken file ever stops the plugin from loading, clear the component cache with `omarchy-restart-shell`.

To copy the whole plugin at once (it prunes stale files but keeps `.git`, so a git-managed install survives):
```bash
./install.sh --plugin-only
```

Validate plugin:
```bash
omarchy plugin validate ~/.config/omarchy/plugins/bisma.omaga-sync
```

---

## 📜 License

Distributed under the **[MIT License](LICENSE)** © 2026 Bisma.
