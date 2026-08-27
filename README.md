# Omaga Sync

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Omarchy](https://img.shields.io/badge/Platform-Omarchy%20%2F%20Quickshell-ff5555.svg)](https://github.com/basecamp/omarchy)
[![Engine: MEGAcmd](https://img.shields.io/badge/Engine-MEGAcmd%20Server-d9272e.svg)](https://github.com/meganz/MEGAcmd)

> **Tags / Topics:** `omarchy`, `quickshell`, `megasync`, `mega`, `hyprland`, `wayland`, `cloud-sync`, `statusbar-widget`, `systemd`

[English](README.md) | [Bahasa Indonesia](README_ID.md)

---

**Omaga Sync** is an official [MEGAcmd](https://github.com/meganz/MEGAcmd) two-way sync integration for the **Omarchy** desktop environment (Quickshell / Wayland / Hyprland). Designed as a lightweight, reliable, headless replacement for the standard MEGAsync desktop app—free of Wayland rendering glitches.

## Architecture

```text
mega-cmd-server ── systemd (omaga-sync-engine.service)     Official MEGAcmd sync engine
      │ Local socket
omaga-sync monitor ── systemd (omaga-sync-monitor.service) 5s poll → status.json
      │ File-watch                                              └─ notify-send on errors
Bar Widget (bisma.omaga-sync) ── QML panel + interactive controls (Pause, Resume, Add, Remove, Logout)
```

## Key Features

- **Dynamic Status Bar Indicator:**
  - Status icons for synced, smooth pulse animation while syncing, dimmed when paused, and red accent on error/offline states.
- **Rich Interactive Panel:**
  - Account info, storage usage progress bar (used vs. total quota).
  - List of local ↔ remote folder pairs with real-time sync state per folder.
  - Global & per-folder **Pause / Resume** toggles.
  - **Remove Sync** button (safe; files on both ends remain untouched).
  - **Interactive Remote Folder Picker**: select any remote MEGA folder to sync into `~/MEGA` without touching the terminal.
  - Session management with **Logout** button and terminal-assisted **Login** onboarding.
- **Bilingual Internationalization (i18n):**
  - English (`en`) and Bahasa Indonesia (`id`) with automatic system locale detection or configurable widget setting.
- **Spam-Free Desktop Notifications:**
  - Alerts sent only when action is required (session expired, engine offline, or folder sync error).
- **Systemd Supervision & Auto-Healing:**
  - Keeps `mega-cmd-server` supervised under systemd user session.

## Installation

### 1. Prerequisite: Install MEGAcmd
```bash
omarchy pkg aur add megacmd
```

### 2. Install Plugin & Services
Run the installer to copy QML files, CLI binaries, and systemd units:
```bash
git clone https://github.com/bismawy/omaga-sync.git
cd omaga-sync
./install.sh
```

### 3. Log in to MEGA (One-time)
```bash
mega-login your-email@example.com
```
*(Or click the Login button directly from the bar panel to launch the interactive login helper).*

## CLI Commands (`omaga-sync`)

The `omaga-sync` utility can be executed directly from terminal or scripts:

| Command | Description |
|---|---|
| `omaga-sync status` | Print current status JSON from monitor |
| `omaga-sync pause [folder]` | Pause syncing for a specific folder or all folders |
| `omaga-sync resume [folder]` | Resume syncing for a specific folder or all folders |
| `omaga-sync add <mega-folder> [base]` | Pair remote MEGA folder to local directory (default `~/MEGA`) |
| `omaga-sync remove <local-folder>` | Remove sync pair (files remain safe on local & cloud) |
| `omaga-sync logout` | Log out of active MEGA session |
| `omaga-sync login [email]` | Launch interactive terminal login helper |
| `omaga-sync open <folder>` | Open local folder in default file manager (`xdg-open`) |
| `omaga-sync repair` | Terminate unmanaged server instances and restart via systemd |

## Development & Hot Reload

To reload QML / JS changes without restarting daemon services:
```bash
./install.sh --plugin-only
```

Validate plugin:
```bash
omarchy plugin validate ~/.config/omarchy/plugins/bisma.omaga-sync
```

## License

[MIT License](LICENSE) © 2026 Bisma
