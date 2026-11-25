// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Controls.Popup {
  id: panel
  required property var readCards
  property var cards: []
  readonly property var filtered: cards.filter(card =>
    (!onlyLord.checked || card.lord) && card.name.includes(search.text.trim()))
  function refresh() {
    if (visible) cards = Array.from(readCards() || []);
  }
  objectName: "qiaoDiscardPanel"
  width: Math.min(530, parent.width - 16)
  height: Math.min(380, parent.height - 16)
  x: Math.round((parent.width - width) / 2)
  y: Math.round((parent.height - height) / 2)
  padding: 12
  focus: true
  onOpened: refresh()
  onClosed: { search.clear(); onlyLord.checked = false; }

  contentItem: ColumnLayout {
    spacing: 6
    RowLayout {
      Layout.fillWidth: true
      Controls.Label { text: "弃牌堆  ·  " + panel.cards.length + " 张"; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
      Controls.Button { text: "关闭"; onClicked: panel.close() }
    }
    RowLayout {
      Layout.fillWidth: true
      Controls.TextField { id: search; objectName: "discardSearch"; placeholderText: "搜索牌名"; Layout.fillWidth: true }
      Controls.CheckBox { id: onlyLord; objectName: "lordFilter"; text: "仅君主装备" }
    }
    GridView {
      id: grid
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      cellWidth: width / Math.max(1, Math.floor(width / 112))
      cellHeight: 64
      model: panel.filtered
      Controls.ScrollBar.vertical: Controls.ScrollBar {}
      delegate: Item {
        required property var modelData
        width: grid.cellWidth; height: grid.cellHeight
        Rectangle {
          anchors.fill: parent; anchors.margins: 3
          color: modelData.lord ? "#faebc5" : "#eeece4"
          border.color: modelData.lord ? "#ab792e" : "#c6c0b3"; radius: 4
          Column {
            anchors.fill: parent; anchors.margins: 6
            Text {
              width: parent.width; font.pixelSize: 13
              color: modelData.suit === "heart" || modelData.suit === "diamond" ? "#9e302e" : "#3e3931"
              text: (({ spade:"♠", heart:"♥", club:"♣", diamond:"♦" })[modelData.suit] || "") +
                    (modelData.rank || "") + (modelData.lord ? "  君主装备" : "")
            }
            Text { width: parent.width; elide: Text.ElideRight; color: "#26231e"; text: modelData.name; font.pixelSize: 16 }
          }
        }
      }
      Controls.Label {
        anchors.centerIn: parent; visible: !grid.count
        text: panel.cards.length ? "没有符合条件的牌" : "弃牌堆为空"
      }
    }
  }
}
