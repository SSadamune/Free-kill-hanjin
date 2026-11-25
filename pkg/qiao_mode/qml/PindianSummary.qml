// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: summary
  required property var record
  required property var translate
  property bool compact: false
  readonly property var targets: compact ? record.targets.slice(0, 2) : record.targets
  implicitHeight: content.implicitHeight + 20
  color: "#282a30"
  border.color: "#786c54"
  radius: 6

  function label(card) {
    const symbol = ({ spade:"♠", heart:"♥", club:"♣", diamond:"♦" })[card.suit] || "";
    const face = symbol + card.rank;
    const points = ({"A":1, "J":11, "Q":12, "K":13, "X":0})[card.rank] ?? Number(card.rank);
    return face + (points === card.points ? "" : " → " + card.points + "点");
  }

  ColumnLayout {
    id: content
    x: 10; y: 10; width: parent.width - 20; spacing: 4
    Text {
      Layout.fillWidth: true; color: "#f0d197"; font.bold: true; elide: Text.ElideRight
      textFormat: Text.PlainText
      text: "第 " + record.sequence + " 次" + (record.joint ? "共同拼点" : "拼点") +
            (record.reason ? " · " + summary.translate(record.reason) : "")
    }
    Repeater {
      model: summary.record.source ? [summary.record.source].concat(summary.targets) : []
      RowLayout {
        required property var modelData
        required property int index
        Layout.fillWidth: true; spacing: 6
        Text { color: "#d8d7d2"; text: modelData.seat + "号位"; font.pixelSize: 14 }
        Text {
          Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText
          color: "#fff9ec"; font.pixelSize: 15; text: summary.translate(modelData.name)
        }
        Text {
          color: modelData.suit === "heart" || modelData.suit === "diamond" ? "#ffab9d" : "#e5e1d8"
          text: summary.label(modelData); font.pixelSize: 14
        }
        Text {
          color: "#f0d197"; font.pixelSize: 13
          text: index === 0 ? "发起" : summary.record.joint ? "" :
                modelData.winner ? modelData.winner + "号胜" : "平点"
        }
      }
    }
    Text {
      visible: summary.targets.length < record.targets.length
      color: "#dad4c8"; text: "另有 " + (record.targets.length - summary.targets.length) + " 名角色，点开查看"
    }
    Text {
      visible: !!record.joint; color: "#f0d197"; font.bold: true
      text: record.winner ? record.winner + "号位获胜" : "无人获胜"
    }
  }
}
