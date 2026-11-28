// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk

Item {
  id: tag
  objectName: "qiaoPortraitStatusLabel"
  required property var entry
  required property bool hovered
  required property bool expanded
  required property bool covered
  required property bool interactive
  required property real inset
  signal activated()

  readonly property string label: [entry?.title, entry?.value].filter(Boolean).join(" ")
  readonly property real foldedWidth: width - 2 * inset
  property real expansion: expanded ? 1 : 0
  Behavior on expansion { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
  z: expanded ? 2 : expansion > 0 ? 1 : 0

  // The drawing can leave the slot. Hover and clicks use only the slot itself.
  Item {
    objectName: "qiaoPortraitStatusFace"
    x: tag.inset - (tag.x + tag.inset) * tag.expansion
    width: tag.foldedWidth + (tag.parent.width - tag.foldedWidth) * tag.expansion
    height: tag.height
    opacity: tag.covered ? 0 : 1
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: 4
      color: "#3C3229"
      opacity: 0.8
      border.color: "white"
      border.width: 1
    }

    Text {
      anchors.fill: parent
      anchors.leftMargin: 1
      anchors.rightMargin: 1
      clip: true
      text: tag.label
      textFormat: Text.PlainText
      wrapMode: Text.NoWrap
      font.family: Config.libianName
      font.pixelSize: 16
      font.letterSpacing: -0.6
      verticalAlignment: Text.AlignVCenter
      color: "white"
      style: Text.Outline
    }
  }

  Controls.AbstractButton {
    anchors.fill: parent
    visible: !!(tag.entry?.action || tag.entry?.qml)
    enabled: tag.interactive
    background: null
    contentItem: null
    Accessible.name: tag.label
    onClicked: tag.activated()
  }

  Controls.ToolTip {
    visible: tag.hovered && !!tag.entry?.description
    delay: 300
    text: tag.entry?.description ?? ""
    font.family: "SimHei"
    font.pixelSize: 16
    width: Math.min(implicitWidth, (tag.Window.window?.width ?? Config.winWidth) * 0.4)
    x: (tag.width - width) / 2
    y: -height - 3
  }
}
