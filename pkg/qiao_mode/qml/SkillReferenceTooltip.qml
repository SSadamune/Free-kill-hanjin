// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls

Popup {
  id: root
  objectName: "qiaoSkillReferenceTooltip"

  required property Item viewport
  required property var entries
  required property point linkPosition
  required property string html
  property bool dismissOnOutsideClick: false

  signal referenceClicked(string link, point position)

  modal: true
  dim: false
  closePolicy: dismissOnOutsideClick ? Popup.CloseOnPressOutside : Popup.NoAutoClose
  padding: 12
  width: Math.min(380, Math.max(0, viewport.width - 16))
  height: Math.min(body.height + 2 * padding, Math.max(0, viewport.height - 16))
  x: Math.max(8, Math.min(linkPosition.x, viewport.width - width - 8))
  y: {
    const below = linkPosition.y + 12;
    if (below + height <= viewport.height - 8) return below;
    return Math.max(8, linkPosition.y - height - 12);
  }

  background: Rectangle {
    color: "#292620"
    border.color: "#A6967A"
    radius: 5
  }

  contentItem: Flickable {
    clip: true
    contentHeight: body.height
    ScrollBar.vertical: ScrollBar {}

    TextEdit {
      id: body
      objectName: "qiaoSkillTooltipBody"
      width: parent.width
      color: "#E4D5A0"
      textFormat: TextEdit.RichText
      readOnly: true
      selectByMouse: false
      wrapMode: TextEdit.Wrap
      font.pixelSize: 16
      text: root.html
      property point pressedAt
      onLinkActivated: link => root.referenceClicked(link, pressedAt)

      TapHandler {
        onPressedChanged: {
          if (pressed) body.pressedAt = body.mapToItem(root.viewport, point.position);
        }
      }
    }
  }
}
