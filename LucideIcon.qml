import QtQuick
import Quickshell.Io

// Lucide SVG icon (icons/<name>.svg), recolored to the active theme without
// extra modules: the SVG text is loaded, its currentColor strokes are
// rewritten to the requested color, and the result is fed to Image as a
// data URL. Qt rasterizes SVG sources at sourceSize, so icons stay crisp.
Item {
  id: root

  property string name: ""
  property real iconSize: 16
  property color color: "#ffffff"

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  property string _raw: ""

  function hexOf(c) {
    function h(v) {
      var s = Math.round(v * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  readonly property string _svg: _raw !== ""
    ? "data:image/svg+xml;utf8," + encodeURIComponent(
        _raw
          .replace(/width="\d+"/, "")
          .replace(/height="\d+"/, "")
          .replace(/currentColor/g, hexOf(color)))
    : ""

  FileView {
    id: svgFile
    path: root.name !== "" ? Qt.resolvedUrl("icons/" + root.name + ".svg") : ""
    printErrors: false
    watchChanges: false
    onLoaded: root._raw = text()
    onLoadFailed: root._raw = ""
  }

  Image {
    anchors.fill: parent
    source: root._svg
    sourceSize.width: Math.max(1, Math.round(root.iconSize * 2))
    sourceSize.height: Math.max(1, Math.round(root.iconSize * 2))
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
  }
}
