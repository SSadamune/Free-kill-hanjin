// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk

Controls.AbstractButton {
  id: button
  objectName: "qiaoCiButton"
  required property var cards
  visible: cards != null
  hoverEnabled: true
  implicitWidth: 21
  implicitHeight: 21
  padding: 0
  text: Lua.tr("@[qiao_ci]")
  Accessible.name: text + " " + (cards?.length ?? 0)

  Controls.ToolTip {
    visible: button.visible && button.hovered
    delay: 300
    text: Lua.tr(":@[qiao_ci]")
  }

  background: Rectangle {
    radius: 4
    color: button.down ? "#383020" : "#59432b"
    border.color: button.hovered || button.visualFocus ? "#fff0b4" : "#cfaa64"
  }
  contentItem: Text {
    text: button.text
    font.family: Config.libianName
    font.pixelSize: 17
    color: "#ffdf99"
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
  Text {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text: button.cards?.length ?? 0
    visible: button.cards != null && button.cards.length !== 1
    font.bold: true
    font.pixelSize: 11
    color: "white"
    style: Text.Outline
    styleColor: "#392918"
  }
}
