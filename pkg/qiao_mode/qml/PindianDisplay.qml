// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Item {
  id: display
  required property var cardPicture
  property var result: null
  readonly property real cardWidth: result ? Math.min(76, width / result.cards.length - 3) : 0
  height: faces.height
  visible: result !== null
  enabled: false

  function clear() { dismiss.stop(); result = null; }
  function present(data) { result = data; dismiss.restart(); }
  function outcome(seat) { return seat ? seat + " 号位赢得拼点" : "双方都没赢"; }
  Timer { id: dismiss; interval: 3000; onTriggered: display.clear() }

  component Caption: Text {
    width: parent.width
    color: "white"; font.bold: true; font.pixelSize: 13
    style: Text.Outline; styleColor: "#25201b"
    textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
    horizontalAlignment: Text.AlignHCenter
  }
  Column {
    id: faces
    width: display.result ? display.result.cards.length * (display.cardWidth + 3) - 3 : 0
    anchors.horizontalCenter: parent.horizontalCenter
    Row {
      spacing: 3
      Repeater {
        model: display.result ? display.result.cards : []
        Column {
          required property var modelData
          required property int index
          width: display.cardWidth
          Rectangle {
            width: parent.width; height: width * 1.40
            color: "#eee7d8"; clip: true
            Image { anchors.fill: parent; source: display.cardPicture(modelData.name) }
            Rectangle {
              anchors.left: parent.left; anchors.top: parent.top
              width: value.implicitWidth + 5; height: value.implicitHeight + 2; color: "#fff5e8"
              Text {
                id: value; anchors.centerIn: parent
                color: ["heart","diamond"].includes(modelData.suit) ? "#a02e27" : "#231f1c"
                font.bold: true; font.pixelSize: 13
                text: (({spade:"♠",club:"♣",heart:"♥",diamond:"♦"})[modelData.suit] || "") +
                      modelData.rank + (modelData.number === modelData.points ? "" : " → " + modelData.points)
              }
            }
            Rectangle {
              anchors.bottom: parent.bottom; width: parent.width; height: seat.implicitHeight + 2; color: "#dc28231f"
              Caption { id: seat; text: modelData.seat + " 号位" }
            }
          }
          Caption {
            visible: index > 0 && !!display.result && !display.result.joint && display.result.cards.length > 2
            text: visible ? display.outcome(modelData.winner) : ""
          }
        }
      }
    }
    Caption {
      visible: !!display.result && (display.result.joint || display.result.cards.length === 2)
      text: !visible ? "" : display.result.joint
            ? (display.result.winner ? display.outcome(display.result.winner) : "无人获胜")
            : display.outcome(display.result.cards[1].winner)
    }
  }
}
