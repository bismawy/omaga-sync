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
  tt_sync_contents: { id: "Sinkronkan sebagai subfolder ~/MEGA/<nama>", en: "Sync as subfolder ~/MEGA/<name>" },
  new_remote_placeholder: { id: "Folder baru di MEGA…", en: "New MEGA folder…" },
  tt_create_and_sync: { id: "Buat folder di MEGA dan sinkronkan", en: "Create on MEGA and sync" },

  // Sections & Content
  sec_activity: { id: "AKTIVITAS SINKRONISASI", en: "SYNC ACTIVITY" },
  tab_syncs: { id: "Sinkron", en: "Syncs" },
  tab_history: { id: "Riwayat", en: "History" },
  tab_logs: { id: "Log", en: "Logs" },
  sec_logs: { id: "LOG MASALAH SINKRONISASI", en: "SYNC ISSUE LOG" },
  logs_empty: { id: "Tidak ada masalah sinkronisasi. Semua path bisa disinkronkan MEGA.", en: "No sync issues. Every path is syncable by MEGA." },
  tt_copy_log: { id: "Salin log ini", en: "Copy this log" },
  tt_copy_all_logs: { id: "Salin semua log", en: "Copy all logs" },
  tt_copied: { id: "Tersalin", en: "Copied" },
  tt_reload_logs: { id: "Muat ulang log", en: "Reload logs" },
  sec_history: { id: "RIWAYAT TRANSFER", en: "TRANSFER HISTORY" },
  history_empty: { id: "Belum ada transfer selesai yang tercatat. Riwayat mulai terisi setelah transfer berikutnya selesai.", en: "No completed transfers recorded yet. History fills in after the next transfer finishes." },
  retention_label: { id: "HAPUS OTOMATIS SETELAH", en: "AUTO-DELETE AFTER" },
  retention_never: { id: "Simpan selamanya", en: "Keep forever" },
  tt_clear_history: { id: "Hapus semua riwayat", en: "Clear all history" },
  downloading_files: { id: "Mengunduh", en: "Downloading" },
  uploading_files: { id: "Mengunggah", en: "Uploading" },
  files_count: { id: "file", en: "files" },
  state_retrying: { id: "mengulang", en: "retrying" },
  state_queued: { id: "antre", en: "queued" },
  state_transferring: { id: "proses", en: "transferring" },
  state_completed: { id: "selesai", en: "completed" },
  state_failed: { id: "gagal", en: "failed" },
  sec_usage: { id: "PENGGUNAAN", en: "USAGE" },
  sec_folders: { id: "FOLDER", en: "FOLDERS" },
  no_folders: { id: "Belum ada folder yang disinkronkan. Tambahkan lewat “Tambah sinkronisasi” di bawah.", en: "No synced folders yet. Add one with “Add sync” below." },
  add_sync: { id: "Tambah sinkronisasi", en: "Add sync" },
  add_sync_desc: { id: "Tambah folder dari akun MEGA sebagai subfolder", en: "Add a MEGA folder as a subfolder" },
  dest_label: { id: "Folder muncul di dalam:", en: "Folders appear inside:" },
  loading_folders: { id: "Memuat daftar folder MEGA… (±1 menit)", en: "Loading MEGA folder list… (±1 min)" },
  pick_already_synced: { id: "sudah tersinkron", en: "already synced" },
  pick_local_used: { id: "dipakai/tercakup sinkronisasi lain — hapus pair itu dulu", en: "used by or inside another sync — remove that pair first" },

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
