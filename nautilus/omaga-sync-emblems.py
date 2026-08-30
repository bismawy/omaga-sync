"""Nautilus emblems for omaga-sync (GNOME Files 4.x / python-nautilus).

Reads ~/.local/state/omaga-sync/status.json (written by the engine every few
seconds) and badges:
  - each synced folder pair with its state  (syncing / synced / paused / error)
  - files currently being transferred       (upload or download)

Emblem icons live in the hicolor user theme as emblem-omaga-*.svg.
"""
import json
import os
import stat
import time

import gi

gi.require_version("Nautilus", "4.1")
from gi.repository import Nautilus, GObject  # noqa: E402

STATUS_FILE = os.environ.get(
    "OMAGA_STATUS_FILE",
    os.path.expanduser("~/.local/state/omaga-sync/status.json"),
)

# Bounded like the panel reader: never trust a huge/odd status file.
MAX_STATUS_BYTES = 65536
CACHE_TTL = 2.0

_STATE_EMBLEMS = {
    "syncing": "emblem-omaga-syncing",
    "synced": "emblem-omaga-synced",
    "paused": "emblem-omaga-paused",
    "error": "emblem-omaga-error",
}
_TRANSFER_EMBLEM = "emblem-omaga-transfer"

_cache = {"ts": 0.0, "pairs": {}, "files": {}}


def _load_status():
    now = time.monotonic()
    if now - _cache["ts"] < CACHE_TTL:
        return
    _cache["ts"] = now
    pairs, files = {}, {}
    try:
        fd = os.open(STATUS_FILE, os.O_RDONLY | os.O_NOFOLLOW)
        try:
            st = os.fstat(fd)
            if not stat.S_ISREG(st.st_mode) or st.st_size > MAX_STATUS_BYTES:
                raise ValueError("bad status file")
            data = json.loads(os.read(fd, MAX_STATUS_BYTES))
        finally:
            os.close(fd)
    except (OSError, ValueError):
        pass
    else:
        for pair in data.get("pairs") or []:
            local = str(pair.get("local") or "")
            emblem = _STATE_EMBLEMS.get(str(pair.get("state") or ""))
            if local and emblem:
                pairs[local] = emblem
        for tr in data.get("activeTransfers") or []:
            local = str(tr.get("dest") or "") if tr.get("type") == "download" \
                else str(tr.get("path") or "")
            if local:
                files[local] = _TRANSFER_EMBLEM
    _cache["pairs"] = pairs
    _cache["files"] = files


class OmagaSyncEmblems(GObject.Object, Nautilus.InfoProvider):

    def update_file_info(self, item):
        _load_status()
        try:
            path = item.get_location().get_path() or ""
        except Exception:
            return
        if not path:
            return
        emblem = _cache["files"].get(path) or _cache["pairs"].get(path)
        if emblem:
            item.add_emblem(emblem)
