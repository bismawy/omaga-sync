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

  readonly property bool enginePaused: syncState === "paused"
  readonly property bool hasError: syncState === "error"
  readonly property bool needsAuth: syncState === "auth"
  readonly property bool isBusy: syncState === "syncing" || syncState === "starting"
  readonly property bool unhealthy: hasError || needsAuth || syncState === "offline"

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
  readonly property color heroColor: unhealthy ? urgentColor : (enginePaused || state === "offline" ? dim : foreground)

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

  function runCtl(sub) {
    if (actionProcess.running) return
    actionProcess.command = [ctlBin, sub]
    actionProcess.running = true
  }

  function togglePause() {
    runCtl(enginePaused ? "resume" : "pause")
  }

  function openFolder(path) {
    var folder = String(path || "")
    if (folder === "") return
    Quickshell.execDetached([ctlBin, "open", folder])
  }

  function copyToClipboard(value) {
    var text = String(value || "")
    if (text === "") return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
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
    var s = String(raw || "").toUpperCase()
    if (s.indexOf("FAIL") !== -1 || s.indexOf("ERROR") !== -1) return qsTr("gagal")
    if (s.indexOf("PAUSE") !== -1) return qsTr("dijeda")
    if (s === "SYNCED" || s === "") return qsTr("tersinkron")
    return s.toLowerCase()
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
        Text {
          anchors.centerIn: parent
          text: "\uE33D"
          color: root.unhealthy ? root.urgentColor : root.foreground
          opacity: root.enginePaused || root.syncState === "offline" ? 0.55 : 1.0
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon

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
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
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
        contentHeight: column.implicitHeight
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
            iconOpacity: root.unhealthy ? 1.0 : (root.enginePaused ? 0.5 : 1.0)
            iconComponent: Component {
              Text {
                text: "\uE33D"
                color: root.heroColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                id: pauseSwitch
                checked: !root.enginePaused
                busy: false
                hasCursor: false
                foreground: hero.foreground
                onHovered: function(on) {}
                onToggled: root.togglePause()

                PanelToolTip {
                  visible: pauseSwitch.containsMouse
                  text: root.enginePaused ? qsTr("Lanjutkan sinkronisasi") : qsTr("Jeda sinkronisasi")
                  fontFamily: hero.fontFamily
                }
              }
            }
          }

          Text {
            visible: root.hasError || root.syncState === "offline"
            width: parent.width
            text: root.syncState === "offline"
              ? qsTr("Mesin MEGAcmd tidak merespons. Periksa: journalctl --user -u omaga-sync-engine")
              : qsTr("Ada folder yang gagal disinkronkan. Periksa panel di bawah.")
            color: root.urgentColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          // Login onboarding: the session is created interactively in a
          // terminal (2FA prompt included), never through the panel.
          Column {
            visible: root.needsAuth
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: qsTr("Sesi MEGA belum ada. Jalankan di terminal, lalu tunggu beberapa detik:")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Text {
                Layout.fillWidth: true
                text: "mega-login email-anda"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideMiddle
              }

              PanelActionButton {
                iconText: "\uF018F"
                tooltipText: qsTr("Salin perintah")
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.copyToClipboard("mega-login email-anda")
              }
            }
          }

          // Quota usage, same rail vocabulary as the clock's year bar.
          Column {
            visible: root.totalBytes > 0
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("PENGGUNAAN")
                color: Qt.darker(root.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }

              Text {
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

                  Text {
                    text: "\uF0209"
                    color: pairRow.modelData && String(pairRow.modelData.state || "").toUpperCase().indexOf("FAIL") !== -1
                      ? root.urgentColor : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
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
                      text: pairRow.modelData ? root.pairStateLabel(pairRow.modelData.state) : ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
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
