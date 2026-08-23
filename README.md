# Omaga Sync

Sinkronisasi dua arah MEGA untuk Omarchy — pengganti headless MEGAsync.
Mesin resmi [MEGAcmd](https://github.com/meganz/MEGAcmd) (SDK yang sama
dengan aplikasi desktop, tanpa GUI = tanpa bug tampilan di Wayland/Hyprland),
status & kontrol lewat widget di bar Omarchy.

```
mega-cmd-server ── systemd (omaga-sync-engine)   mesin sync dua arah
      │ socket lokal
omaga-sync monitor ── systemd (omaga-sync-monitor)   poll 5 dtk → status.json
      │ file-watch                                        └ notify-send saat error
Widget bar (bisma.omaga-sync) ── baca status.json, tombol jeda/lanjut/buka folder
```

## Fitur

- Ikon cloud di bar: normal / berdenyut saat sync / merah saat error / redup saat jeda
- Klik: panel detail (akun, kuota, daftar folder + statusnya)
- Jeda/lanjutkan sync (klik kanan ikon atau saklar di panel)
- Klik baris folder: buka foldernya
- Notifikasi desktop **hanya saat error** (login kedaluwarsa, sync gagal, server mati) — tanpa spam

## Instalasi

```bash
omarchy pkg aur add megacmd   # sekali; build dari source, bisa lama
./install.sh
```

Setup akun (sekali saja, di terminal — prompt 2FA interaktif):

```bash
mega-login email-anda
mega-sync ~/Sync /Sync        # pasangan folder lokal ↔ folder MEGA
```

## Perintah

| Perintah | Efek |
|---|---|
| `omaga-sync status` | status terakhir (JSON) |
| `omaga-sync pause` / `resume` | jeda / lanjutkan seluruh sync |
| `omaga-sync open <folder>` | buka folder sync |
| `journalctl --user -u omaga-sync-engine` | log mesin MEGA |

## Development

Repo adalah sumber kebenaran; plugin di `~/.config/omarchy/plugins/` harus
berupa salinan (loader menolak symlink). Setelah edit:

```bash
./install.sh --plugin-only   # salin + hot-reload
```

Validasi: `omarchy plugin validate ~/.config/omarchy/plugins/bisma.omaga-sync`
dan `qmllint -I "$OMARCHY_PATH/shell" Panel.qml`.
