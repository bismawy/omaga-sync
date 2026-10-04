import QtQuick
import qs.Commons
import qs.Ui

// Small square icon button for panel actions, mirroring PanelActionButton's
// role but rendering a Material Symbols SVG instead of a font glyph.
BorderSurface {
  id: root

  property string iconName: ""
  property string tooltipText: ""
  property color foreground: Color.foreground
  property color iconColor: root.enabled ? root.foreground : Qt.darker(root.foreground, 2.0)
  property real iconSize: Style.font.heading
  property real size: Math.max(Style.space(28), iconSize + Style.spacing.sm * 2)
  // Spin the icon a full turn on click (reload buttons).
  property bool spinOnClick: false

  signal clicked()

  implicitWidth: size
  implicitHeight: size
  radius: Style.cornerRadius

  readonly property bool _hot: mouse.containsMouse && root.enabled

  color: _hot ? Style.hoverFillFor(foreground, foreground) : "transparent"
  borderSpec: Border.none()

  Behavior on color { ColorAnimation { duration: 60 } }

  Item {
    id: iconHost
    anchors.centerIn: parent
    width: root.iconSize
    height: root.iconSize
    rotation: 0

    MaterialIcon {
      anchors.centerIn: parent
      name: root.iconName
      iconSize: root.iconSize
      color: root.iconColor
    }
  }

  NumberAnimation {
    id: spinAnim
    target: iconHost
    property: "rotation"
    from: 0
    to: 360
    duration: 600
    easing.type: Easing.OutCubic
    onFinished: iconHost.rotation = 0
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (root.spinOnClick && !spinAnim.running) {
        iconHost.rotation = 0
        spinAnim.start()
      }
      root.clicked()
    }
  }

  PanelToolTip {
    visible: root.tooltipText !== "" && mouse.containsMouse
    text: root.tooltipText
    fontFamily: Style.font.family
  }
}
