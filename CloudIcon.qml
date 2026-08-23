import QtQuick
import qs.Commons
import qs.Ui

// Cloud silhouette drawn from primitives (same approach as TailscaleIcon):
// cloud glyphs vary across Nerd Font builds and read badly at bar sizes, so
// the shape is owned here and renders identically everywhere.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize * (17 / 24)
  implicitWidth: width
  implicitHeight: height

  // 24x17 design grid scaled to the requested width.
  readonly property real s: width / 24

  Rectangle { // base slab
    x: 3 * root.s
    y: 11 * root.s
    width: 17.5 * root.s
    height: 5.5 * root.s
    radius: 2.75 * root.s
    color: root.color
  }

  Rectangle { // large puff
    x: 9.5 * root.s
    y: 3 * root.s
    width: 10 * root.s
    height: 10 * root.s
    radius: 5 * root.s
    color: root.color
  }

  Rectangle { // small puff
    x: 4 * root.s
    y: 6.5 * root.s
    width: 7 * root.s
    height: 7 * root.s
    radius: 3.5 * root.s
    color: root.color
  }
}
