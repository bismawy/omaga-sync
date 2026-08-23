import QtQuick
import qs.Commons
import qs.Ui

// Small square icon button for panel actions, mirroring PanelActionButton's
// role but rendering a Lucide SVG instead of a font glyph.
BorderSurface {
  id: root

  property string iconName: ""
  property Component iconComponent: null
  property string tooltipText: ""
  property color foreground: Color.foreground
  property color iconColor: root.enabled ? root.foreground : Qt.darker(root.foreground, 2.0)
  property real iconSize: Style.font.icon
  property real size: Math.max(Style.space(26), iconSize + Style.spacing.sm * 2)

  signal clicked()

  implicitWidth: size
  implicitHeight: size
  radius: Style.cornerRadius

  readonly property bool _hot: mouse.containsMouse && root.enabled

  color: _hot ? Style.hoverFillFor(foreground, foreground) : "transparent"
  borderSpec: Border.none()

  Behavior on color { ColorAnimation { duration: 60 } }

  Loader {
    anchors.centerIn: parent
    visible: root.iconComponent !== null
    sourceComponent: root.iconComponent
  }

  LucideIcon {
    anchors.centerIn: parent
    visible: root.iconComponent === null
    name: root.iconName
    iconSize: root.iconSize
    color: root.iconColor
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.clicked()
  }

  PanelToolTip {
    visible: root.tooltipText !== "" && mouse.containsMouse
    text: root.tooltipText
    fontFamily: Style.font.family
  }
}
