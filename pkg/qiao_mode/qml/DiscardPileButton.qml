// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk

Controls.AbstractButton {
  id: button
  required property int count
  text: "弃牌堆"
  width: 50
  height: 46
  padding: 0
  hoverEnabled: true
  Accessible.name: text + " " + count + " 张"
  Controls.ToolTip.visible: hovered
  Controls.ToolTip.delay: 400
  Controls.ToolTip.text: Accessible.name

  contentItem: Item {
    Repeater {
      model: [
        { x: 5, y: 7, angle: -24, pip: "♠", ink: "#573828" },
        { x: 12, y: 4, angle: -8, pip: "♥", ink: "#8e4637" },
        { x: 21, y: 5, angle: 11, pip: "♦", ink: "#8e4637" }
      ]
      Rectangle {
        id: card
        required property var modelData
        required property int index
        x: modelData.x
        y: modelData.y + (button.down ? 2 : 0)
        width: 25
        height: 35
        radius: 3
        rotation: modelData.angle
        border.color: button.hovered || button.activeFocus ? "#e9be7e" : "#8c6447"
        gradient: Gradient {
          GradientStop { position: 0; color: "#f3deb2" }
          GradientStop { position: 0.47; color: "#c9a378" }
          GradientStop { position: 1; color: "#8e6649" }
        }
        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          radius: 2
          color: "transparent"
          border.color: "#88ffebbf"
        }
        Text {
          x: 3
          y: 1
          text: card.modelData.pip
          color: card.modelData.ink
          font.family: Config.libianName
          font.pixelSize: 9
        }
        Text {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: 2
          visible: card.index === 2
          rotation: -card.rotation
          text: button.count
          color: "#fff4dd"
          font.family: Config.libianName
          font.pixelSize: button.count < 100 ? 22 : 15
          style: Text.Outline
          styleColor: "#39271d"
        }
      }
    }
  }
}
