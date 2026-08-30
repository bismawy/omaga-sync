import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

// Omaga Sync — MEGA two-way sync in the Omarchy bar.
//
// The MEGAcmd engine (systemd unit omaga-sync-engine) does the
// syncing; ~/.local/bin/omaga-sync monitor keeps status.json fresh; this
// widget only reads that file (file-watch driven) and routes actions back
// through the omaga-sync control command.
Panel {
  id: root
  moduleName: "bisma.omaga-sync"
  ipcTarget: "bisma.omaga-sync"
  manageIpc: false

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string ctlBin: home + "/.local/bin/omaga-sync"
  readonly property string statusPath: home + "/.local/state/omaga-sync/status.json"

  property var status: null
  property string statusError: ""
  property bool addMode: false
  property string activeTab: "syncs"
  property var history: []
  property string historyError: ""

  readonly property string syncState: status ? String(status.state || "") : ""
  readonly property var pairs: status && status.pairs instanceof Array ? status.pairs : []
  readonly property var remoteFolders: status && status.remoteFolders instanceof Array ? status.remoteFolders : []
  readonly property var activeTransfers: status && status.activeTransfers instanceof Array ? status.activeTransfers : []
  readonly property var transfersSummary: status && status.transfersSummary ? status.transfersSummary : null
  readonly property int downloadsCount: transfersSummary ? Number(transfersSummary.downloadsCount || 0) : 0
  readonly property int downloadsTotalCount: transfersSummary ? Number(transfersSummary.downloadsTotalCount || 0) : 0
  readonly property int downloadsCompletedCount: transfersSummary ? Number(transfersSummary.downloadsCompletedCount || 0) : 0
  readonly property int uploadsCount: transfersSummary ? Number(transfersSummary.uploadsCount || 0) : 0
  readonly property int uploadsTotalCount: transfersSummary ? Number(transfersSummary.uploadsTotalCount || 0) : 0
  readonly property int uploadsCompletedCount: transfersSummary ? Number(transfersSummary.uploadsCompletedCount || 0) : 0
  readonly property int historyRetentionDays: status ? Number(status.historyRetentionDays || 0) : 0
  readonly property string retentionValue: historyRetentionDays === 0 ? "never" : String(historyRetentionDays)

  readonly property bool hasTransfers: activeTransfers.length > 0 || downloadsCount > 0 || uploadsCount > 0
  readonly property bool loggedIn: ["synced", "syncing", "paused", "error"].indexOf(syncState) !== -1
  readonly property string email: status ? String(status.email || "") : ""
  readonly property real usedBytes: status ? Number(status.usedBytes || 0) : 0
  readonly property real totalBytes: status ? Number(status.totalBytes || 0) : 0
  readonly property real quotaFraction: totalBytes > 0 ? Math.min(1, usedBytes / totalBytes) : 0

  readonly property bool allPaused: syncState === "paused"
  readonly property bool hasError: syncState === "error"
  readonly property bool needsAuth: syncState === "auth"
  readonly property bool isBusy: syncState === "syncing" || syncState === "starting"
  // Red is reserved for genuine breakage; "needs login" stays neutral white.
  readonly property bool broken: hasError || syncState === "offline"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgentColor: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string lang: I18n.resolveLang(setting("language", "auto"))

  function t(key) {
    return I18n.tr(key, lang)
  }

  readonly property string stateLabel: {
    switch (syncState) {
      case "synced": return t("state_synced")
      case "syncing": return t("state_syncing")
      case "starting": return t("state_starting")
      case "auth": return t("state_auth")
      case "offline": return t("state_offline")
      case "paused": return t("state_paused")
      case "error": return t("state_error")
      default: return t("state_loading")
    }
  }
  readonly property string metaLabel: {
    var parts = [stateLabel]
    if (syncState === "syncing") {
      var sum = transfersSummaryText()
      if (sum !== "") parts.push(sum)
    }
    if (status && status.updatedTs) parts.push(Qt.formatDateTime(new Date(status.updatedTs * 1000), "HH:mm"))
    return parts.join(" · ")
  }
  readonly property color heroColor: broken ? urgentColor : (allPaused ? dim : foreground)

  function parseStatusText(raw) {
    var str = String(raw || "")
    if (str.length === 0) return
    if (str.length > 65536) {
      statusError = "Status data exceeded size limit"
      return
    }
    try {
      var parsed = JSON.parse(str)
      if (parsed && typeof parsed === "object") {
        if (parsed.pairs instanceof Array && parsed.pairs.length > 50) {
          parsed.pairs = parsed.pairs.slice(0, 50)
        }
        if (parsed.remoteFolders instanceof Array && parsed.remoteFolders.length > 100) {
          parsed.remoteFolders = parsed.remoteFolders.slice(0, 100)
        }
        if (parsed.activeTransfers instanceof Array && parsed.activeTransfers.length > 6) {
          parsed.activeTransfers = parsed.activeTransfers.slice(0, 6)
        }
        status = parsed
        statusError = ""
      }
    } catch (e) {
      statusError = String(e)
    }
  }

  function refresh() {
    if (statusReader.running) statusReader.running = false
    statusReader.running = true
  }

  function refreshHistory() {
    if (historyReader.running) historyReader.running = false
    historyReader.running = true
  }

  function parseHistoryText(raw) {
    var str = String(raw || "")
    if (str === "") {
      historyError = "history reader returned nothing"
      return
    }
    if (str.length > 65536) {
      historyError = "History data exceeded size limit"
      return
    }
    try {
      var parsed = JSON.parse(str)
      var entries = parsed && parsed.entries instanceof Array ? parsed.entries : []
      // newest first, capped
      history = entries.slice(Math.max(0, entries.length - 100)).reverse()
      historyError = ""
    } catch (e) {
      historyError = String(e)
    }
  }

  function formatHistoryTime(ts) {
    var d = new Date(Number(ts || 0) * 1000)
    if (d.getTime() <= 0) return ""
    var now = new Date()
    return d.toDateString() === now.toDateString()
      ? Qt.formatDateTime(d, "HH:mm")
      : Qt.formatDateTime(d, "dd MMM HH:mm")
  }

  function runCtl(sub, path) {
    var cmd = path !== undefined && path !== ""
      ? [ctlBin, sub, path]
      : [ctlBin, sub]
    Quickshell.execDetached(cmd)
    actionRefresh.restart()
  }

  function runCtlArgs(argv) {
    Quickshell.execDetached([ctlBin].concat(argv))
    actionRefresh.restart()
  }

  function togglePause() {
    runCtl(allPaused ? "resume" : "pause")
  }

  function openFolder(path) {
    var folder = String(path || "")
    if (folder === "") return
    Quickshell.execDetached([ctlBin, "open", folder])
  }

  function formatBytes(bytes) {
    if (!bytes || bytes <= 0) return "0 B"
    var units = ["B", "KB", "MB", "GB", "TB"]
    var value = bytes
    var unit = 0
    while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++ }
    return (unit === 0 ? value : value.toFixed(1)) + " " + units[unit]
  }

  // Transfers whose local side lives inside the given sync pair folder.
  // Uploads carry the local path in `path` (source), downloads in `dest`.
  function pairTransfersFor(localPath) {
    if (!localPath || localPath === "" || !root.activeTransfers) return []
    var out = []
    for (var i = 0; i < root.activeTransfers.length; i++) {
      var tr = root.activeTransfers[i]
      var p = String(tr.type) === "upload" ? String(tr.path || "") : String(tr.dest || "")
      if (p.indexOf(localPath) === 0) out.push(tr)
    }
    return out
  }

  function pairStateLabel(raw) {
    switch (String(raw || "")) {
      case "error": return t("pair_error")
      case "paused": return t("pair_paused")
      case "syncing": return t("pair_syncing")
      case "synced": return t("pair_synced")
      default: return t("pair_checking")
    }
  }

  function transferStateLabel(st) {
    switch (String(st || "").toLowerCase()) {
      case "retrying": return t("state_retrying")
      case "queued": return t("state_queued")
      case "active":
      case "transferring":
      case "syncing": return t("state_transferring")
      case "completed": return t("state_completed")
      case "failed":
      case "error": return t("state_failed")
      default: return String(st || "")
    }
  }

  function transfersSummaryText() {
    if (!transfersSummary) return ""
    var parts = []
    if (downloadsCount > 0 || downloadsCompletedCount > 0) {
      var dlTotal = downloadsTotalCount > 0 ? downloadsTotalCount : downloadsCount
      var dlRatio = downloadsCompletedCount + "/" + dlTotal + " " + t("files_count")
      parts.push(t("downloading_files") + " " + dlRatio + " (" + transfersSummary.downloadTotal + ")")
    }
    if (uploadsCount > 0 || uploadsCompletedCount > 0) {
      var ulTotal = uploadsTotalCount > 0 ? uploadsTotalCount : uploadsCount
      var ulRatio = uploadsCompletedCount + "/" + ulTotal + " " + t("files_count")
      parts.push(t("uploading_files") + " " + ulRatio + " (" + transfersSummary.uploadTotal + ")")
    }
    return parts.join(" · ")
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root, direction)
    return false
  }

  // Pick state for a remote folder: "synced" (paired), "taken" (its
  // destination subfolder collides with or sits inside another pair's
  // root — MEGA forbids overlapping syncs), or "available".
  function pickState(name) {
    var dest = root.home + "/" + localBaseField.text + "/" + name
    for (var i = 0; i < root.pairs.length; i++) {
      var pair = root.pairs[i]
      var pl = String(pair.local || "")
      if (String(pair.remote || "") === "/" + name) return "synced"
      if (pl === dest || dest.indexOf(pl + "/") === 0 || pl.indexOf(dest + "/") === 0)
        return "taken"
    }
    return "available"
  }

  function pickDest(name) {
    return root.home + "/" + localBaseField.text + "/" + name
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    refresh()
    if (activeTab === "history") refreshHistory()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  } else {
    addMode = false
    activeTab = "syncs"
  }

  onAddModeChanged: {
    if (!addMode && pickFlick) {
      pickFlick.contentY = 0
    }
  }

  // Watch-only: FileView never loads file content into the shell
  // (blockLoading). It exists purely to notice status.json changing.
  FileView {
    id: statusFile
    path: root.statusPath
    watchChanges: true
    blockLoading: true
    preload: false
    printErrors: false
    onFileChanged: root.refresh()
  }

  // Bounded reader: `omaga-sync status` enforces regular-file type,
  // no-symlink (O_NOFOLLOW) and a 64 KB byte cap BEFORE any byte reaches
  // QML. Only its capped stdout is parsed here.
  Process {
    id: statusReader
    command: [root.ctlBin, "status"]
    stdout: StdioCollector {
      onStreamFinished: root.parseStatusText(this.text)
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) root.statusError = "status reader refused the file"
    }
  }

  // Same bounded-read contract, for the transfer history file.
  Process {
    id: historyReader
    command: [root.ctlBin, "history"]
    stdout: StdioCollector {
      onStreamFinished: root.parseHistoryText(this.text)
    }
  }

  // Belt and braces: the file watch is the fast path, a slow poll covers a
  // missed rename (the monitor writes atomically via replace).
  Timer {
    interval: 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      root.refresh()
      if (root.opened && root.activeTab === "history") root.refreshHistory()
    }
  }

  Timer {
    id: actionRefresh
    interval: 800
    repeat: false
    onTriggered: {
      root.refresh()
      if (root.opened) root.refreshHistory()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string { return root.syncState }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        MaterialIcon {
          anchors.centerIn: parent
          name: "folder-m"
          iconSize: Style.bar.iconCanvas
          color: root.broken ? root.urgentColor : root.foreground
          opacity: root.allPaused || root.syncState === "offline" ? 0.55 : 1.0

          SequentialAnimation on opacity {
            running: root.isBusy
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
          }
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(700))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: emailField.activeFocus || localBaseField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: root.email !== "" ? root.email : "MEGA Sync"
            meta: root.statusError !== "" && !root.status ? t("monitor_not_running")
              : root.metaLabel
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.broken ? 1.0 : (root.allPaused ? 0.5 : 1.0)
            iconComponent: Component {
              MaterialIcon {
                name: "folder-m"
                iconSize: Style.font.display
                color: root.heroColor
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.space(4)

                IconButton {
                  iconName: "refresh"
                  tooltipText: t("tt_reload_status")
                  foreground: root.foreground
                  iconSize: Style.font.heading
                  spinOnClick: true
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: root.refresh()
                }

                IconButton {
                  visible: root.loggedIn
                  iconName: "logout"
                  tooltipText: t("tt_logout")
                  foreground: root.foreground
                  iconSize: Style.font.heading
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: root.runCtl("logout")
                }

                ToggleSwitch {
                  id: pauseSwitch
                  checked: !root.allPaused
                  busy: false
                  hasCursor: false
                  foreground: Color.accent
                  accent: Color.accent
                  anchors.verticalCenter: parent.verticalCenter
                  onHovered: function(on) {}
                  onToggled: root.togglePause()

                  PanelToolTip {
                    visible: pauseSwitch.containsMouse
                    text: root.allPaused ? t("tt_resume_all") : t("tt_pause_all")
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            visible: root.broken
            width: parent.width
            textFormat: Text.PlainText
            text: root.syncState === "offline"
              ? t("server_offline_msg")
              : (root.status && root.status.message ? String(root.status.message) : t("folder_error_msg"))
            color: root.urgentColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          // Login onboarding: MEGAcmd has no browser/OAuth flow, so the
          // button opens the default terminal with `mega-login <email>`
          // pre-filled; only the password and 2FA code are typed there.
          Item {
            visible: root.needsAuth
            width: parent.width
            height: visible ? loginSection.implicitHeight : 0

            Column {
              id: loginSection
              width: parent.width
              spacing: Style.space(8)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: t("login_prompt")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                TextField {
                  id: emailField
                  Layout.fillWidth: true
                  placeholderText: t("email_placeholder")
                  color: root.foreground
                  font.family: root.fontFamily
                  inputMethodHints: Qt.ImhEmailCharactersOnly
                  onAccepted: root.runCtl("login", text)
                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                      keyCatcher.forceActiveFocus()
                      event.accepted = true
                    }
                  }
                  onActiveFocusChanged: if (!activeFocus) keyCatcher.forceActiveFocus()
                }
              }

              Rectangle {
                id: loginRow
                width: parent.width
                height: loginInner.implicitHeight + Style.space(10)
                radius: Style.cornerRadius
                color: loginMouse.containsMouse
                  ? Style.hoverFillFor(root.foreground, Color.accent)
                  : "transparent"

                RowLayout {
                  id: loginInner
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(10)

                  MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "login"
                    iconSize: Style.font.heading
                    color: root.foreground
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(1)

                    Text {
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      text: t("login_title")
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }

                    Text {
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      text: t("login_subtitle")
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                }

                MouseArea {
                  id: loginMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runCtl("login", emailField.text)
                }
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: t("login_manual_hint")
                color: Qt.darker(root.foreground, 1.9)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
          }

          // Quota usage, same rail vocabulary as the clock's year bar.
          Item {
            visible: root.totalBytes > 0
            width: parent.width
            height: visible ? quotaSection.implicitHeight : 0

            Column {
              id: quotaSection
              width: parent.width
              spacing: Style.space(6)

              Item {
                id: quotaHeader
                width: parent.width
                height: Math.max(quotaLabel.implicitHeight, quotaValue.implicitHeight)

                Text {
                  id: quotaLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: t("sec_usage")
                  color: Qt.darker(root.foreground, 1.5)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                }

                Text {
                  id: quotaValue
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.formatBytes(root.usedBytes) + " / " + root.formatBytes(root.totalBytes)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Rectangle {
                width: parent.width
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.quotaFraction)
                  height: parent.height
                  radius: parent.radius
                  color: root.quotaFraction > 0.9 ? root.urgentColor
                    : Color.accent

                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }
            }
          }

          // Tabs: live sync state vs recorded transfer history.
          Item {
            visible: root.loggedIn
            width: parent.width
            height: visible ? tabsRow.implicitHeight : 0

            ButtonGroup {
              id: tabsRow
              width: parent.width
              options: [
                { value: "syncs", label: root.t("tab_syncs") },
                { value: "history", label: root.t("tab_history") }
              ]
              value: root.activeTab
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) {
                root.activeTab = v
                if (v === "history") root.refreshHistory()
              }
            }
          }

          // Sync Activity: real-time transfer progress and active files
          Item {
            visible: root.hasTransfers && !root.allPaused && root.loggedIn && root.activeTab === "syncs"
            width: parent.width
            height: visible ? activitySection.implicitHeight : 0

            Column {
              id: activitySection
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: t("sec_activity")
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                visible: text !== ""
                width: parent.width
                textFormat: Text.PlainText
                text: root.transfersSummaryText()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Flickable {
                id: activityFlick
                width: parent.width
                height: Math.min(activityColumn.implicitHeight, Style.space(170))
                implicitHeight: height
                contentWidth: width
                contentHeight: activityColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                  id: activityColumn
                  width: parent.width
                  spacing: Style.space(4)

                  Repeater {
                    model: root.activeTransfers

                    Rectangle {
                      id: transferRow
                      required property var modelData
                      width: parent.width
                      height: transferInner.implicitHeight + Style.space(6)
                      radius: Style.cornerRadius
                      color: Style.hoverFillFor(root.foreground, Color.accent)

                      RowLayout {
                        id: transferInner
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(8)

                        MaterialIcon {
                          name: transferRow.modelData && transferRow.modelData.type === "upload" ? "cloud_upload" : "cloud_download"
                          iconSize: Style.font.heading
                          color: transferRow.modelData && transferRow.modelData.state === "retrying" ? root.urgentColor : Color.accent
                          Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(1)

                          Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: transferRow.modelData ? String(transferRow.modelData.file || "") : ""
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideMiddle
                          }

                          Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: transferRow.modelData ? String(transferRow.modelData.progress || "") : ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                          }
                        }

                        Rectangle {
                          Layout.alignment: Qt.AlignVCenter
                          radius: Style.cornerRadius > 0 ? height / 2 : 0
                          color: {
                            var st = transferRow.modelData ? String(transferRow.modelData.state || "") : ""
                            if (st === "retrying") return Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.2)
                            return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                          }
                          implicitWidth: stateText.implicitWidth + Style.space(10)
                          implicitHeight: stateText.implicitHeight + Style.space(4)

                          Text {
                            id: stateText
                            anchors.centerIn: parent
                            textFormat: Text.PlainText
                            text: transferRow.modelData ? root.transferStateLabel(transferRow.modelData.state) : ""
                            color: {
                              var st = transferRow.modelData ? String(transferRow.modelData.state || "") : ""
                              if (st === "retrying") return root.urgentColor
                              return Color.accent
                            }
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator {
            visible: root.activeTab === "syncs" && (root.pairs.length > 0 || root.syncState === "synced")
            foreground: root.foreground
          }

          Item {
            visible: root.activeTab === "syncs" && (root.pairs.length > 0 || root.syncState === "synced")
            width: parent.width
            height: visible ? foldersSection.implicitHeight : 0

            Column {
              id: foldersSection
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: t("sec_folders")
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Text {
                visible: root.pairs.length === 0
                width: parent.width
                textFormat: Text.PlainText
                text: t("no_folders")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              Repeater {
                model: root.pairs

                Rectangle {
                  id: pairRow
                  required property var modelData
                  readonly property string pairState: modelData ? String(modelData.state || "") : ""
                  readonly property bool pairPaused: pairState === "paused"
                  readonly property bool pairFailed: pairState === "error"
                  readonly property var pairTransfers: root.pairTransfersFor(modelData ? String(modelData.local || "") : "")
                  readonly property string transfersTooltip: {
                    if (pairTransfers.length === 0) return ""
                    var names = []
                    for (var i = 0; i < Math.min(pairTransfers.length, 3); i++)
                      names.push(String(pairTransfers[i].file || ""))
                    if (pairTransfers.length > 3) names.push("+" + (pairTransfers.length - 3))
                    return names.join("\n")
                  }

                  width: parent.width
                  height: pairInner.implicitHeight + Style.space(8)
                  radius: Style.cornerRadius
                  color: folderClickArea.containsMouse
                    ? Style.hoverFillFor(root.foreground, Color.accent)
                    : "transparent"

                  RowLayout {
                    id: pairInner
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(8)

                    MouseArea {
                      id: folderClickArea
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.openFolder(pairRow.modelData ? String(pairRow.modelData.local || "") : "")

                      PanelToolTip {
                        visible: folderClickArea.containsMouse
                        text: pairRow.transfersTooltip !== "" ? pairRow.transfersTooltip : t("tt_open_folder")
                        fontFamily: root.fontFamily
                      }

                      RowLayout {
                        anchors.fill: parent
                        spacing: Style.space(8)

                        Item {
                          Layout.alignment: Qt.AlignVCenter
                          implicitWidth: Style.font.heading
                          implicitHeight: Style.font.heading

                          MaterialIcon {
                            anchors.fill: parent
                            name: "folder"
                            iconSize: Style.font.heading
                            color: pairRow.pairFailed ? root.urgentColor
                              : pairRow.pairPaused ? Qt.darker(root.dim, 1.3) : Color.accent
                          }

                          // Transfer emblem, like a Nautilus symlink badge.
                          MaterialIcon {
                            visible: pairRow.pairTransfers.length > 0
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -Style.space(3)
                            anchors.bottomMargin: -Style.space(3)
                            name: "refresh"
                            iconSize: Math.max(10, Math.round(Style.font.heading * 0.55))
                            color: Color.accent

                            NumberAnimation on rotation {
                              from: 0
                              to: 360
                              duration: 1500
                              loops: Animation.Infinite
                              running: parent.visible
                            }
                          }
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(1)

                          Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: pairRow.modelData ? String(pairRow.modelData.local || "") : ""
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            elide: Text.ElideMiddle
                          }

                          Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            textFormat: Text.PlainText
                            text: {
                              if (!pairRow.modelData) return ""
                              var detail = String(pairRow.modelData.error || "").trim()
                              if (pairRow.pairFailed && detail !== "" && detail.toUpperCase() !== "NO") return detail
                              if (pairRow.pairTransfers.length > 0) {
                                var tr = pairRow.pairTransfers[0]
                                var file = String(tr.file || "")
                                var prog = String(tr.progress || "")
                                if (file !== "" && prog !== "") return file + " — " + prog
                                return file !== "" ? file : prog
                              }
                              return root.pairStateLabel(pairRow.pairState)
                            }
                            color: pairRow.pairFailed ? root.urgentColor : root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                          }
                        }
                      }
                    }

                    IconButton {
                      tooltipText: pairRow.pairPaused ? t("tt_resume_folder") : t("tt_pause_folder")
                      foreground: root.foreground
                      iconSize: Style.font.heading
                      iconComponent: pairRow.pairPaused ? playGlyph : pauseGlyph
                      Layout.alignment: Qt.AlignVCenter
                      onClicked: root.runCtl(pairRow.pairPaused ? "resume" : "pause",
                                             pairRow.modelData ? pairRow.modelData.local : "")
                    }

                    IconButton {
                      iconName: "delete"
                      tooltipText: t("tt_remove_sync")
                      foreground: root.foreground
                      iconSize: Style.font.heading
                      Layout.alignment: Qt.AlignVCenter
                      onClicked: root.runCtl("remove",
                                             pairRow.modelData ? pairRow.modelData.local : "")
                    }
                  }
                }
              }
            }
          }

          // Add-sync entry point — one clear action, like the desktop app's
          // "Add sync" button. Expands into the remote folder picker.
          Rectangle {
            visible: root.loggedIn && root.activeTab === "syncs"
            width: parent.width
            height: addLabelRow.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: addMouse.containsMouse
              ? Style.hoverFillFor(root.foreground, Color.accent)
              : "transparent"

            RowLayout {
              id: addLabelRow
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(10)

              MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "add"
                iconSize: Style.font.heading
                color: root.foreground
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(1)

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: t("add_sync")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: t("add_sync_desc")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }

            MouseArea {
              id: addMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.addMode = !root.addMode
            }
          }

          // Pick-to-sync: the chosen MEGA folder's CONTENTS land directly in
          // the base folder (~/MEGA by default) — same as the desktop app.
          Item {
            id: pickContainer
            visible: root.loggedIn && root.addMode && root.activeTab === "syncs"
            width: parent.width
            height: visible ? pickSection.implicitHeight : 0
            clip: true

            Column {
              id: pickSection
              width: parent.width
              spacing: Style.space(8)

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText
                  text: t("dest_label")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                  id: localBaseField
                  Layout.fillWidth: true
                  text: "MEGA"
                  color: root.foreground
                  font.family: root.fontFamily
                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                      keyCatcher.forceActiveFocus()
                      event.accepted = true
                    }
                  }
                  onActiveFocusChanged: if (!activeFocus) keyCatcher.forceActiveFocus()
                }

                IconButton {
                  iconName: "refresh"
                  tooltipText: t("tt_reload_folder_list")
                  foreground: root.foreground
                  iconSize: Style.font.heading
                  spinOnClick: true
                  Layout.alignment: Qt.AlignVCenter
                  onClicked: root.refresh()
                }
              }

              Text {
                visible: root.remoteFolders.length === 0
                width: parent.width
                textFormat: Text.PlainText
                text: t("loading_folders")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              // Scrollable remote folder list — capped height with smooth internal scrolling
              // so the top controls (Hero, Quota, Folders, and input) stay sticky at the top.
              Flickable {
                id: pickFlick
                width: parent.width
                height: Math.min(pickColumn.implicitHeight, Style.space(220))
                implicitHeight: height
                contentWidth: width
                contentHeight: pickColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                  id: pickColumn
                  width: parent.width
                  spacing: Style.space(4)

                  Repeater {
                    model: root.remoteFolders

                    Rectangle {
                      id: pickRow
                      required property string modelData
                      readonly property string pickState: root.pickState(modelData)
                      readonly property bool pickable: pickState === "available"

                      width: parent.width
                      height: pickInner.implicitHeight + Style.space(8)
                      radius: Style.cornerRadius
                      color: pickMouse.containsMouse && pickable
                        ? Style.hoverFillFor(root.foreground, Color.accent)
                        : "transparent"
                      opacity: pickRow.pickState === "synced" ? 1.0 : (pickable ? 1.0 : 0.4)

                      RowLayout {
                        id: pickInner
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(8)

                        MaterialIcon {
                          name: "folder"
                          iconSize: Style.font.heading
                          color: pickRow.pickState === "synced" ? Color.accent : (pickRow.pickable ? root.foreground : root.dim)
                          Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(1)

                          Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: pickRow.modelData
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            elide: Text.ElideMiddle
                          }

                          Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: {
                              if (pickRow.pickState === "synced") return t("pick_already_synced")
                              if (pickRow.pickState === "taken") return t("pick_local_used")
                              return root.pickDest(pickRow.modelData)
                            }
                            color: pickRow.pickState === "taken" ? root.dim : root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideMiddle
                          }
                        }

                        MaterialIcon {
                          visible: pickRow.pickState === "synced" || !pickRow.pickable
                          name: pickRow.pickState === "synced" ? "cloud" : "cloud_off"
                          iconSize: Style.font.heading
                          color: pickRow.pickState === "synced" ? Color.accent : root.dim
                          Layout.alignment: Qt.AlignVCenter
                        }
                      }

                      MouseArea {
                        id: pickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: pickRow.pickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: pickRow.pickable
                        onClicked: {
                          root.runCtlArgs(["add", pickRow.modelData, localBaseField.text])
                          root.addMode = false
                        }
                      }

                      PanelToolTip {
                        visible: pickMouse.containsMouse && pickRow.pickable
                        text: t("tt_sync_contents")
                        fontFamily: root.fontFamily
                      }
                    }
                  }
                }
              }

              // New cloud folder: creates /<name> on MEGA and syncs it.
              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                MaterialIcon {
                  name: "create_new_folder"
                  iconSize: Style.font.heading
                  color: root.foreground
                  Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                  id: newRemoteField
                  Layout.fillWidth: true
                  placeholderText: t("new_remote_placeholder")
                  color: root.foreground
                  font.family: root.fontFamily
                  onAccepted: {
                    if (text.trim() !== "") {
                      root.runCtlArgs(["add", text.trim(), localBaseField.text])
                      text = ""
                      root.addMode = false
                    }
                  }
                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                      keyCatcher.forceActiveFocus()
                      event.accepted = true
                    }
                  }
                  onActiveFocusChanged: if (!activeFocus) keyCatcher.forceActiveFocus()
                }

                IconButton {
                  iconName: "add"
                  tooltipText: t("tt_create_and_sync")
                  foreground: root.foreground
                  iconSize: Style.font.heading
                  Layout.alignment: Qt.AlignVCenter
                  onClicked: {
                    if (newRemoteField.text.trim() !== "") {
                      root.runCtlArgs(["add", newRemoteField.text.trim(), localBaseField.text])
                      newRemoteField.text = ""
                      root.addMode = false
                    }
                  }
                }
              }
            }
          }

          // History tab: recorded transfers with retention control.
          Item {
            visible: root.loggedIn && root.activeTab === "history"
            width: parent.width
            height: visible ? historySection.implicitHeight : 0

            Column {
              id: historySection
              width: parent.width
              spacing: Style.space(8)

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                PanelSectionHeader {
                  Layout.fillWidth: true
                  text: t("sec_history")
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                IconButton {
                  visible: root.history.length > 0
                  iconName: "delete"
                  tooltipText: t("tt_clear_history")
                  foreground: root.foreground
                  iconSize: Style.font.heading
                  Layout.alignment: Qt.AlignVCenter
                  onClicked: root.runCtlArgs(["clear-history"])
                }
              }

              Text {
                visible: root.historyError !== ""
                width: parent.width
                textFormat: Text.PlainText
                text: root.historyError
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              Text {
                visible: root.history.length === 0 && root.historyError === ""
                width: parent.width
                textFormat: Text.PlainText
                text: t("history_empty")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              // Auto-delete retention: 3–90 days or keep forever.
              Column {
                width: parent.width
                spacing: Style.space(4)

                Text {
                  text: t("retention_label")
                  color: Qt.darker(root.foreground, 1.5)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                }

                ButtonGroup {
                  width: parent.width
                  options: [
                    { value: "never", label: "\u221E", tooltip: t("retention_never") },
                    { value: "3", label: "3d" },
                    { value: "7", label: "7d" },
                    { value: "14", label: "14d" },
                    { value: "30", label: "30d" },
                    { value: "60", label: "60d" },
                    { value: "90", label: "90d" }
                  ]
                  value: root.retentionValue
                  foreground: root.foreground
                  accent: Color.accent
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  focusable: false
                  onChanged: function(v) { root.runCtlArgs(["set-retention", v]) }
                }
              }

              Flickable {
                width: parent.width
                height: Math.min(historyColumn.implicitHeight, Style.space(280))
                implicitHeight: height
                contentWidth: width
                contentHeight: historyColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                  id: historyColumn
                  width: parent.width
                  spacing: Style.space(4)

                  Repeater {
                    model: root.history

                    Rectangle {
                      id: historyRow
                      required property var modelData
                      readonly property bool rowFailed: modelData && modelData.status === "failed"
                      width: parent.width
                      height: historyInner.implicitHeight + Style.space(6)
                      radius: Style.cornerRadius
                      color: Style.hoverFillFor(root.foreground, Color.accent)

                      RowLayout {
                        id: historyInner
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(8)

                        MaterialIcon {
                          name: historyRow.modelData && historyRow.modelData.type === "upload" ? "cloud_upload" : "cloud_download"
                          iconSize: Style.font.heading
                          color: historyRow.rowFailed ? root.urgentColor : Color.accent
                          Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(1)

                          Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: historyRow.modelData ? String(historyRow.modelData.file || "") : ""
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideMiddle
                          }

                          Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            textFormat: Text.PlainText
                            text: historyRow.modelData ? String(historyRow.modelData.lastProgress || "") : ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                          }
                        }

                        Text {
                          Layout.alignment: Qt.AlignVCenter
                          textFormat: Text.PlainText
                          text: root.formatHistoryTime(historyRow.modelData ? historyRow.modelData.endedTs : 0)
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }

                        Text {
                          Layout.alignment: Qt.AlignVCenter
                          textFormat: Text.PlainText
                          text: historyRow.rowFailed ? t("state_failed") : t("state_completed")
                          color: historyRow.rowFailed ? root.urgentColor : Color.accent
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                      }
                    }
                  }
                }
              }
            }
          }

        }
      }
    }

  // Pause/resume pair toggle (Material Symbols filled).
  Component {
    id: pauseGlyph
    MaterialIcon { name: "pause_circle"; color: root.foreground; iconSize: Style.font.heading }
  }

  Component {
    id: playGlyph
    MaterialIcon { name: "play_circle"; color: root.foreground; iconSize: Style.font.heading }
  }
}
