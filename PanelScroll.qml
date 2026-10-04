import QtQuick
import QtQuick.Controls
import qs.Commons

// Vertically scrollable region for the panel's lists: capped to maxHeight, or
// shorter when the list is, and scrollable only once it overflows. The four
// list tabs in Panel.qml repeated this block verbatim, and the fixed height is
// what a panel needs (no Layout involvement here) so the cap is a plain property.
//
// Children are packed into an inner Column at the default property, matching how
// Flickable content is normally declared:
//
//   PanelScroll {
//     id: pickFlick
//     maxHeight: Style.space(220)
//     Repeater { ... }
//   }
Flickable {
  id: root

  property real maxHeight: 0

  default property alias content: contentColumn.data
  readonly property bool overflows: contentHeight > height

  width: parent.width
  contentWidth: width
  contentHeight: contentColumn.implicitHeight
  height: Math.min(contentHeight, maxHeight)
  implicitHeight: height
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  interactive: overflows
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Column {
    id: contentColumn
    width: parent.width
    spacing: Style.space(4)
  }
}