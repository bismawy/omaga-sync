// Omaga Sync — Internationalization dictionary (English & Bahasa Indonesia)

.pragma library

var STRINGS = {
  // State labels
  state_synced: { id: "Tersinkron", en: "Synced" },
  state_syncing: { id: "Sinkronisasi…", en: "Syncing…" },
  state_starting: { id: "Menyambung…", en: "Connecting…" },
  state_auth: { id: "Perlu login", en: "Login required" },
  state_offline: { id: "Server offline", en: "Server offline" },
  state_paused: { id: "Dijeda", en: "Paused" },
  state_error: { id: "Gagal sinkron", en: "Sync failed" },
  state_loading: { id: "Memuat…", en: "Loading…" },

  // Pair item state labels
  pair_error: { id: "gagal", en: "failed" },
  pair_paused: { id: "dijeda", en: "paused" },
  pair_syncing: { id: "menyinkronkan", en: "syncing" },
  pair_synced: { id: "tersinkron", en: "synced" },
  pair_checking: { id: "memeriksa", en: "checking" },

  // Meta & Errors
  monitor_not_running: { id: "Monitor belum berjalan", en: "Monitor not running" },
  server_offline_msg: { id: "Mesin MEGAcmd tidak merespons. Periksa: journalctl --user -u omaga-sync-engine", en: "MEGAcmd engine is not responding. Check: journalctl --user -u omaga-sync-engine" },
  folder_error_msg: { id: "Ada folder yang gagal disinkronkan. Periksa panel di bawah.", en: "A folder failed to sync. Check the panel below." },

  // Tooltips
  tt_resume_all: { id: "Lanjutkan semua sinkronisasi", en: "Resume all syncing" },
  tt_pause_all: { id: "Jeda semua sinkronisasi", en: "Pause all syncing" },
  tt_reload_status: { id: "Muat ulang status", en: "Reload status" },
  tt_logout: { id: "Logout dari akun MEGA", en: "Log out of MEGA account" },
  tt_resume_folder: { id: "Lanjutkan folder ini", en: "Resume this folder" },
  tt_pause_folder: { id: "Jeda folder ini", en: "Pause this folder" },
  tt_remove_sync: { id: "Hapus sync ini (file tetap aman)", en: "Remove this sync (files remain safe)" },
  tt_open_folder: { id: "Buka folder", en: "Open folder" },
  tt_reload_folder_list: { id: "Muat ulang daftar folder", en: "Reload folder list" },
  tt_sync_contents: { id: "Sinkronkan isi folder ini", en: "Sync this folder's contents" },

  // Sections & Content
  sec_usage: { id: "PENGGUNAAN", en: "USAGE" },
  sec_folders: { id: "FOLDER", en: "FOLDERS" },
  no_folders: { id: "Belum ada folder sync. Tambahkan dengan:\nmega-sync ~/Sync /Sync", en: "No sync folders yet. Add one with:\nmega-sync ~/Sync /Sync" },
  add_sync: { id: "Tambah sinkronisasi", en: "Add sync" },
  add_sync_desc: { id: "Pilih folder dari akun MEGA Anda", en: "Choose a folder from your MEGA account" },
  dest_label: { id: "Isi folder masuk ke:", en: "Sync contents to:" },
  loading_folders: { id: "Daftar folder MEGA sedang dimuat… (menyusul dalam ±1 menit)", en: "Loading MEGA folder list… (ready in ±1 min)" },
  pick_already_synced: { id: "sedang disinkronkan", en: "already synced" },
  pick_local_used: { id: "folder lokal dipakai sync lain", en: "local folder used by another sync" },

  // Login Section
  login_prompt: { id: "Sesi MEGA belum ada. Masukkan email, klik Login, lalu isi password dan kode 2FA di terminal yang terbuka:", en: "No active MEGA session. Enter email, click Login, then fill in password & 2FA in the terminal:" },
  email_placeholder: { id: "email MEGA Anda", en: "your MEGA email" },
  login_title: { id: "Login MEGA", en: "Log in to MEGA" },
  login_subtitle: { id: "Buka terminal — tinggal ketik password dan kode 2FA", en: "Opens terminal — just type password and 2FA code" },
  login_manual_hint: { id: "Atau manual di terminal: mega-cmd, lalu ketik: login email-anda", en: "Or in terminal: mega-cmd, then type: login your-email" }
}

function resolveLang(override) {
  var opt = String(override || "auto").toLowerCase().trim()
  if (opt === "id" || opt === "in" || opt === "indonesian") return "id"
  if (opt === "en" || opt === "english") return "en"
  // Auto-detect based on Qt system locale
  try {
    var loc = Qt.locale().name.toLowerCase()
    return loc.indexOf("id") === 0 || loc.indexOf("in") === 0 ? "id" : "en"
  } catch (e) {
    return "en"
  }
}

function tr(key, lang) {
  var item = STRINGS[key]
  if (!item) return key
  return item[lang] || item["en"] || key
}
