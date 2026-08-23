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

  readonly property string syncState: status ? String(status.state || "") : ""
  readonly property var pairs: status && status.pairs instanceof Array ? status.pairs : []
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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
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
      blocked: emailField.activeFocus
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
                iconName: root.allPaused ? "play" : "pause"
                tooltipText: root.allPaused ? qsTr("Lanjutkan semua sinkronisasi") : qsTr("Jeda semua sinkronisasi")
                foreground: root.foreground
                iconSize: Style.font.body
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
              visible: root.pairs.length === 0
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
                    iconName: pairRow.pairPaused ? "play" : "pause"
                    tooltipText: pairRow.pairPaused ? qsTr("Lanjutkan folder ini") : qsTr("Jeda folder ini")
                    foreground: root.foreground
                    iconSize: Style.font.body
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

          Text {
            width: parent.width
            text: qsTr("Klik kanan ikon: jeda/lanjut · klik tengah: muat ulang · p: jeda · r: muat ulang")
            color: Qt.darker(root.foreground, 1.9)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
