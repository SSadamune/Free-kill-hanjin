// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk

Controls.AbstractButton {
  id: button
  required property int count
  text: "弃牌堆"
  width: 42
  height: 46
  padding: 0
  hoverEnabled: true
  Accessible.name: text + " " + count + " 张"
  Controls.ToolTip.visible: hovered
  Controls.ToolTip.delay: 400
  Controls.ToolTip.text: Accessible.name

  contentItem: Item {
    Image {
      x: 5
      y: 3
      width: 27
      height: 36
      rotation: -13
      source: SkinBank.searchBuiltinPic("/image/card/", "card-back")
    }
    Rectangle {
      id: front
      x: 11
      y: button.down ? 5 : 3
      width: 28
      height: 38
      radius: 3
      border.color: button.hovered || button.activeFocus ? "#ffda92" : "#8c6447"
      gradient: Gradient {
        GradientStop { position: 0; color: "#ead4a8" }
        GradientStop { position: 0.43; color: "#b88e66" }
        GradientStop { position: 1; color: "#74513d" }
      }
      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 2
        color: "transparent"
        border.color: "#88ffebbf"
      }
      Rectangle {
        x: 5; y: 5; width: 4; height: 4
        rotation: 45
        color: "#96674c"
      }
      Rectangle {
        x: front.width - 9; y: front.height - 9; width: 4; height: 4
        rotation: 45
        color: "#efcc99"
      }
      Text {
        anchors.centerIn: parent
        text: button.count
        color: "#fff4dd"
        font.family: Config.libianName
        font.pixelSize: button.count < 100 ? 23 : 17
        style: Text.Outline
        styleColor: "#39271d"
      }
    }
  }
}
