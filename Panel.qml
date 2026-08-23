import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Omaga Sync — MEGA two-way sync in the Omarchy bar.
//
// The official MEGAcmd engine (systemd unit omaga-sync-engine) does the
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

  readonly property string syncState: status ? String(status.state || "") : ""
  readonly property var pairs: status && status.pairs instanceof Array ? status.pairs : []
  readonly property var remoteFolders: status && status.remoteFolders instanceof Array ? status.remoteFolders : []
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

  readonly property string stateLabel: {
    switch (syncState) {
      case "synced": return qsTr("Tersinkron")
      case "syncing": return qsTr("Sinkronisasi…")
      case "starting": return qsTr("Menyambung…")
      case "auth": return qsTr("Perlu login")
      case "offline": return qsTr("Server offline")
      case "paused": return qsTr("Dijeda")
      case "error": return qsTr("Gagal sinkron")
      default: return qsTr("Memuat…")
    }
  }
  readonly property string metaLabel: {
    var parts = [stateLabel]
    if (status && status.updatedTs) parts.push(Qt.formatDateTime(new Date(status.updatedTs * 1000), "HH:mm"))
    return parts.join(" · ")
  }
  readonly property color heroColor: broken ? urgentColor : (allPaused ? dim : foreground)

  function parseStatusText(raw) {
    try {
      status = JSON.parse(String(raw))
      statusError = ""
    } catch (e) {
      statusError = String(e)
    }
  }

  function refresh() {
    if (statusFile.path !== "") statusFile.reload()
  }

  function runCtl(sub, path) {
    if (actionProcess.running) return
    actionProcess.command = path !== undefined && path !== ""
      ? [ctlBin, sub, path]
      : [ctlBin, sub]
    actionProcess.running = true
  }

  function runCtlArgs(argv) {
    if (actionProcess.running) return
    actionProcess.command = [ctlBin].concat(argv)
    actionProcess.running = true
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

  function pairStateLabel(raw) {
    switch (String(raw || "")) {
      case "error": return qsTr("gagal")
      case "paused": return qsTr("dijeda")
      case "syncing": return qsTr("menyinkronkan")
      case "synced": return qsTr("tersinkron")
      default: return qsTr("memeriksa")
    }
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root, direction)
    return false
  }

  // Pick state for a remote folder against the base folder field:
  // "synced" (already paired), "taken" (base folder used by another pair),
  // or "available".
  function pickState(name) {
    var base = root.home + "/" + localBaseField.text
    for (var i = 0; i < root.pairs.length; i++) {
      var pair = root.pairs[i]
      if (String(pair.remote || "") === "/" + name) return "synced"
      if (String(pair.local || "") === base) return "taken"
    }
    return "available"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  } else {
    addMode = false
  }

  FileView {
    id: statusFile
    path: root.statusPath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseStatusText(text())
    onLoadFailed: function(error) { root.statusError = String(error || "") }
    onFileChanged: reload()
  }

  // Belt and braces: the file watch is the fast path, a slow poll covers a
  // missed rename (the monitor writes atomically via replace).
  Timer {
    interval: 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: actionRefresh
    interval: 800
    repeat: false
    onTriggered: root.refresh()
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) { actionRefresh.restart() }
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
        LucideIcon {
          anchors.centerIn: parent
          name: "folder-sync"
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
      if (buttonCode === Qt.RightButton) root.togglePause()
      else if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
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
    // childrenRect (actual laid-out height) rather than implicitHeight:
    // mixed implicit/explicit child sizing can leave the positioner's
    // implicitHeight at 0 while the real content height is not.
    contentHeight: panel.fittedContentHeight(Math.max(column.childrenRect.height, column.implicitHeight))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: emailField.activeFocus || localBaseField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "p" || t === "P") root.togglePause()
        else if (t === "r" || t === "R") root.refresh()
      }

        Flickable {
          id: panelFlick
          anchors.fill: parent
          contentWidth: width
          contentHeight: Math.max(column.childrenRect.height, column.implicitHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: root.email !== "" ? root.email : "MEGA Sync"
            meta: root.statusError !== "" && !root.status ? qsTr("Monitor belum berjalan")
              : root.metaLabel
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.broken ? 1.0 : (root.allPaused ? 0.5 : 1.0)
            iconComponent: Component {
              LucideIcon {
                name: "folder-sync"
                iconSize: Style.font.display
                color: root.heroColor
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                id: pauseSwitch
                checked: !root.allPaused
                busy: false
                hasCursor: false
                foreground: hero.foreground
                onHovered: function(on) {}
                onToggled: root.togglePause()

                PanelToolTip {
                  visible: pauseSwitch.containsMouse
                  text: root.allPaused ? qsTr("Lanjutkan semua sinkronisasi") : qsTr("Jeda semua sinkronisasi")
                  fontFamily: hero.fontFamily
                }
              }
            }
          }

          // Visible equivalents of the bar-icon right/middle clicks, so the
          // panel works stand-alone without knowing the mouse shortcuts.
          Item {
            width: parent.width
            height: actionRow.implicitHeight

            Row {
              id: actionRow
              anchors.right: parent.right
              spacing: Style.space(4)

              IconButton {
                tooltipText: root.allPaused ? qsTr("Lanjutkan semua sinkronisasi") : qsTr("Jeda semua sinkronisasi")
                foreground: root.foreground
                iconSize: Style.font.body
                iconComponent: root.allPaused ? playGlyph : pauseGlyph
                onClicked: root.togglePause()
              }

              IconButton {
                iconName: "rotate-cw"
                tooltipText: qsTr("Muat ulang status")
                foreground: root.foreground
                iconSize: Style.font.body
                onClicked: root.refresh()
              }
            }
          }

          Text {
            visible: root.broken
            width: parent.width
            text: root.syncState === "offline"
              ? qsTr("Mesin MEGAcmd tidak merespons. Periksa: journalctl --user -u omaga-sync-engine")
              : qsTr("Ada folder yang gagal disinkronkan. Periksa panel di bawah.")
            color: root.urgentColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          // Login onboarding: MEGAcmd has no browser/OAuth flow, so the
          // button opens the default terminal with `mega-login <email>`
          // pre-filled; only the password and 2FA code are typed there.
          Column {
            visible: root.needsAuth
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: qsTr("Sesi MEGA belum ada. Masukkan email, klik Login, lalu isi password dan kode 2FA di terminal yang terbuka:")
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
                placeholderText: qsTr("email MEGA Anda")
                foreground: root.foreground
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

                LucideIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "log-in"
                iconSize: Style.font.heading
                color: root.foreground
              }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(1)

                  Text {
                    Layout.fillWidth: true
                    text: qsTr("Login MEGA")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    Layout.fillWidth: true
                    text: qsTr("Buka terminal — tinggal ketik password dan kode 2FA")
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
              text: qsTr("Atau manual di terminal: mega-cmd, lalu ketik: login email-anda")
              color: Qt.darker(root.foreground, 1.9)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // Quota usage, same rail vocabulary as the clock's year bar.
          Column {
            visible: root.totalBytes > 0
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
                text: qsTr("PENGGUNAAN")
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }

              Text {
                id: quotaValue
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
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
                  : Style.selectedStateColor(root.foreground, Color.accent)

                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              }
            }
          }

          PanelSeparator {
            visible: root.pairs.length > 0 || root.syncState === "synced"
            foreground: root.foreground
          }

          Column {
            visible: root.pairs.length > 0 || root.syncState === "synced"
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: qsTr("FOLDER")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.pairs.length === 0 && !root.loggedIn
              width: parent.width
              text: qsTr("Belum ada folder sync. Tambahkan dengan:\nmega-sync ~/Sync /Sync")
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

                width: parent.width
                height: pairInner.implicitHeight + Style.space(8)
                radius: Style.cornerRadius
                color: pairMouse.containsMouse
                  ? Style.hoverFillFor(root.foreground, Color.accent)
                  : "transparent"

                RowLayout {
                  id: pairInner
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  LucideIcon {
                    name: "folder"
                    iconSize: Style.font.body
                    color: pairRow.pairFailed ? root.urgentColor
                      : pairRow.pairPaused ? Qt.darker(root.dim, 1.3) : root.dim
                    Layout.alignment: Qt.AlignVCenter
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(1)

                    Text {
                      Layout.fillWidth: true
                      text: pairRow.modelData ? String(pairRow.modelData.local || "") : ""
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideMiddle
                    }

                    Text {
                      Layout.fillWidth: true
                      visible: text !== ""
                      text: {
                        if (!pairRow.modelData) return ""
                        var detail = pairRow.modelData.error || ""
                        return detail !== "" ? detail : root.pairStateLabel(pairRow.pairState)
                      }
                      color: pairRow.pairFailed ? root.urgentColor : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  IconButton {
                    tooltipText: pairRow.pairPaused ? qsTr("Lanjutkan folder ini") : qsTr("Jeda folder ini")
                    foreground: root.foreground
                    iconSize: Style.font.body
                    iconComponent: pairRow.pairPaused ? playGlyph : pauseGlyph
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: root.runCtl(pairRow.pairPaused ? "resume" : "pause",
                                           pairRow.modelData ? pairRow.modelData.local : "")
                  }
                }

                MouseArea {
                  id: pairMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openFolder(pairRow.modelData ? pairRow.modelData.local : "")
                }

                PanelToolTip {
                  visible: pairMouse.containsMouse
                  text: qsTr("Buka folder")
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          // Add-sync entry point — one clear action, like the desktop app's
          // "Add sync" button. Expands into the remote folder picker.
          Rectangle {
            visible: root.loggedIn
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

              Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: plusIconSize
                implicitHeight: plusIconSize
                readonly property real plusIconSize: Style.font.heading

                Rectangle {
                  anchors.centerIn: parent
                  width: parent.width * 0.62
                  height: Math.max(2, parent.height * 0.1)
                  radius: height / 2
                  color: root.foreground
                }
                Rectangle {
                  anchors.centerIn: parent
                  width: Math.max(2, parent.width * 0.1)
                  height: parent.height * 0.62
                  radius: width / 2
                  color: root.foreground
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(1)

                Text {
                  Layout.fillWidth: true
                  text: qsTr("Tambah sinkronisasi")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  Layout.fillWidth: true
                  text: qsTr("Pilih folder dari akun MEGA Anda")
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
          Column {
            visible: root.loggedIn && root.addMode
            width: parent.width
            spacing: Style.space(8)

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: qsTr("Isi folder masuk ke:")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                Layout.alignment: Qt.AlignVCenter
              }

              TextField {
                id: localBaseField
                Layout.fillWidth: true
                text: "MEGA"
                foreground: root.foreground
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
                iconName: "rotate-cw"
                tooltipText: qsTr("Muat ulang daftar folder")
                foreground: root.foreground
                iconSize: Style.font.body
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.refresh()
              }
            }

            Text {
              visible: root.remoteFolders.length === 0
              width: parent.width
              text: qsTr("Daftar folder MEGA sedang dimuat… (menyusul dalam ±1 menit)")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

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
                opacity: pickable ? 1.0 : (pickState === "synced" ? 0.5 : 0.35)

                RowLayout {
                  id: pickInner
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  LucideIcon {
                    name: "folder"
                    iconSize: Style.font.body
                    color: root.dim
                    Layout.alignment: Qt.AlignVCenter
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(1)

                    Text {
                      Layout.fillWidth: true
                      text: pickRow.modelData
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideMiddle
                    }

                    Text {
                      Layout.fillWidth: true
                      text: {
                        if (pickRow.pickState === "synced") return qsTr("sedang disinkronkan")
                        if (pickRow.pickState === "taken") return qsTr("folder lokal dipakai sync lain")
                        return root.home + "/" + localBaseField.text
                      }
                      color: pickRow.pickState === "available" ? root.dim : Qt.darker(root.dim, 1.2)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }
                  }

                  LucideIcon {
                    visible: pickRow.pickState !== "available"
                    name: pickRow.pickState === "synced" ? "cloud" : "cloud-off"
                    iconSize: Style.font.body
                    color: root.dim
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
                  text: qsTr("Sinkronkan isi folder ini")
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          Text {
            width: parent.width
            text: qsTr("Klik kanan ikon bar: jeda/lanjut semua")
            color: Qt.darker(root.foreground, 1.9)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // Filled pause/play glyphs: outline glyphs read as muddled at these sizes,
  // so solid shapes are drawn directly.
  component FilledPause: Item {
    id: glyph
    property color color: "#ffffff"
    property real iconSize: 14
    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    Rectangle {
      x: 0
      width: parent.width * 0.34
      height: parent.height
      radius: width / 2
      color: glyph.color
    }
    Rectangle {
      anchors.right: parent.right
      width: parent.width * 0.34
      height: parent.height
      radius: width / 2
      color: glyph.color
    }
  }

  component FilledPlay: Item {
    id: glyph
    property color color: "#ffffff"
    property real iconSize: 14
    implicitWidth: iconSize * 0.85
    implicitHeight: iconSize
    width: iconSize * 0.85
    height: iconSize

    Canvas {
      id: triangle
      anchors.fill: parent
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = glyph.color
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(width, height / 2)
        ctx.lineTo(0, height)
        ctx.closePath()
        ctx.fill()
      }
      Connections {
        target: glyph
        function onColorChanged() { triangle.requestPaint() }
      }
    }
  }

  Component {
    id: pauseGlyph
    FilledPause { color: root.foreground; iconSize: Style.font.body }
  }

  Component {
    id: playGlyph
    FilledPlay { color: root.foreground; iconSize: Style.font.body }
  }
}
