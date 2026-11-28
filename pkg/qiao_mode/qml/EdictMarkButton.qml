// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk

Controls.AbstractButton {
  id: button
  objectName: "qiaoEdictMark"
  required property var count
  visible: count !== false
  hoverEnabled: true
  implicitWidth: 21
  implicitHeight: 21
  padding: 0
  text: Lua.tr("qiao_em_han001_zhaoshu")
  Accessible.name: text + " " + count

  background: Image {
    source: SkinBank.getMarkPic("qiao_edict")
    fillMode: Image.PreserveAspectFit
  }
  contentItem: Text {
    text: button.visible ? button.count : ""
    horizontalAlignment: Text.AlignRight
    verticalAlignment: Text.AlignBottom
    font.bold: true
    font.pixelSize: 12
    color: "white"
    style: Text.Outline
    styleColor: "#392918"
  }
  Controls.ToolTip {
    visible: button.visible && button.hovered
    delay: 300
    text: button.text + "　" + Lua.tr(":qiao_edict")
  }
}
