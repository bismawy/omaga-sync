import QtQuick
import Quickshell
import qs.Commons

// Single-line text input for the panel, built on TextEdit instead of TextField.
//
// Why not TextField: Qt connects every live QQuickTextInput to
// QClipboard::dataChanged, and its paste check calls QMimeData::text(), which
// downloads the whole selection from the owner. On Wayland that read goes
// through QWaylandMimeData::readData(), which loops with a per-chunk timeout
// and no total byte or time bound, so a clipboard owner that keeps the pipe
// trickling blocks the shared shell. TextEdit's check
// (QQuickTextControl::canInsertFromMimeData) only asks hasText()/hasFormat(),
// and on Wayland QWaylandMimeData::hasFormat_sys() is answered from the
// offer's cached MIME list, so neither the payload nor the owner is contacted.
// Every automatic path in TextEdit — dataChanged, canPaste, and the readOnly
// change — is therefore format-only.
//
// The remaining payload paths are user gestures, and this component closes the
// two it can: Ctrl+V / Ctrl+X / Shift+Insert are consumed before TextEdit's own
// shortcut handling (Keys.priority BeforeItem), and the middle click that
// TextEdit binds to the general selection is taken by an overlay that accepts
// only that button. Nothing here reaches the unbounded read loop.
TextEdit {
  id: field

  property alias placeholderText: placeholder.text
  property bool hasCursor: false

  signal accepted()
  signal escapePressed()

  readonly property bool _focused: activeFocus
  readonly property bool _hot: hoverHandler.hovered || hasCursor
  readonly property var _borderSpec: Border.controlSpec(_focused ? "focus" : (_hot ? "hover-cursor" : "normal"), color, Color.accent)
  readonly property int _padX: Style.spacing.controlPaddingX + Border.left(_borderSpec)
  readonly property int _padY: Style.spacing.inputPaddingY + Border.top(_borderSpec)

  text: ""
  textFormat: TextEdit.PlainText
  wrapMode: TextEdit.NoWrap
  selectByMouse: true
  cursorVisible: activeFocus
  verticalAlignment: TextEdit.AlignVCenter
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  selectionColor: Style.selectionFillFor(color, Color.accent)
  selectedTextColor: color
  leftPadding: _padX
  rightPadding: _padX
  topPadding: _padY
  bottomPadding: _padY
  implicitHeight: Math.ceil(contentHeight) + topPadding + bottomPadding

  // In-process Wayland selection write, the same path the Logs tab copy uses:
  // no child process, so no MEGA path can reach an argv.
  function copySelection() { Quickshell.clipboardText = field.selectedText }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    // Bounded clipboard policy: consume exactly the keys that would make the
    // control fetch the selection, and nothing else.
    if (event.matches(StandardKey.Paste) || event.matches(StandardKey.Cut)
        || (event.key === Qt.Key_Insert && (event.modifiers & Qt.ShiftModifier))
        || (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier))) {
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Escape) {
      field.escapePressed()
      event.accepted = true
      return
    }
    if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
        && !(event.modifiers & Qt.ShiftModifier)) {
      field.accepted()
      event.accepted = true
    }
  }

  // A pointer handler, not a MouseArea: it tracks hover and sets the cursor
  // without consuming clicks, so selection dragging stays intact.
  HoverHandler {
    id: hoverHandler
    cursorShape: Qt.IBeamCursor
  }

  // TextEdit pastes the general selection on middle click. That path reads the
  // primary selection through the same unbounded loop, so it is taken here.
  // Only MiddleButton is accepted, so a left press still reaches the text.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onPressed: function(mouse) { mouse.accepted = true }
  }

  Rectangle {
    anchors.fill: parent
    z: -1
    radius: Style.cornerRadius
    color: Style.controlFill(field._focused, field._hot, field.color, Color.accent)
    border.color: field._borderSpec.color
    border.width: Math.max(Border.top(field._borderSpec), Border.bottom(field._borderSpec))
  }

  Text {
    id: placeholder
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: field.leftPadding
    anchors.rightMargin: field.rightPadding
    anchors.verticalCenter: parent.verticalCenter
    visible: field.text.length === 0
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Qt.darker(field.color, 1.6)
    font: field.font
  }
}
