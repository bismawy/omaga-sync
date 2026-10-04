import QtQuick
import qs.Commons

// The panel's muted wrapping note (empty states, hints, error strings).
// Ink and font are pinned to the panel theme, so callers only carry layout
// and the text itself — the three-property preamble this replaced repeated
// eight times in Panel.qml.
Text {
  id: root

  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.bodySmall

  // PlainText: an empty-state hint or an MEGA reason can contain < or &, and
  // must never be parsed as rich text.
  textFormat: Text.PlainText
  color: Qt.darker(foreground, 1.55)
  font.family: fontFamily
  font.pixelSize: fontSize
  wrapMode: Text.WordWrap
}