// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Controls.Popup {
  id: panel
  required property var readCards
  signal inspect(int cardId)
  property var cards: []
  readonly property var filtered: cards.filter(card =>
    (!onlyLord.checked || card.lord) && card.name.includes(search.text.trim()))
  function refresh() {
    if (!visible) return;
    const atTop = grid.atYBeginning;
    const offset = Math.max(0, grid.contentY - grid.originY);
    const columns = Math.max(1, Math.round(grid.width / grid.cellWidth));
    const first = Math.floor(offset / grid.cellHeight) * columns;
    const old = filtered;
    cards = Array.from(readCards() || []);
    grid.forceLayout();
    if (atTop || !grid.count) { grid.positionViewAtBeginning(); return; }
    const indices = new Map(filtered.map((card, i) => [card.id, i]));
    let nextOffset = offset;
    for (let i = first; i < old.length; i++) {
      if (old[i].id === undefined || !indices.has(old[i].id)) continue;
      const rowChange = Math.floor(indices.get(old[i].id) / columns) - Math.floor(i / columns);
      nextOffset += rowChange * grid.cellHeight;
      break;
    }
    grid.contentY = grid.originY + Math.max(0, Math.min(nextOffset, grid.contentHeight - grid.height));
  }
  objectName: "qiaoDiscardPanel"
  width: Math.min(530, parent.width - 16)
  height: Math.min(380, parent.height - 16)
  x: Math.round((parent.width - width) / 2)
  y: Math.round((parent.height - height) / 2)
  padding: 12
  focus: true
  onOpened: refresh()
  onClosed: { search.clear(); onlyLord.checked = false; grid.positionViewAtBeginning(); }

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
      id: grid; objectName: "discardGrid"
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      cellWidth: width / Math.max(1, Math.floor(width / 112))
      cellHeight: 76
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
            Text { width: parent.width; elide: Text.ElideRight; color: "#57412d"; text: modelData.marks || ""; font.pixelSize: 12 }
          }
          TapHandler { enabled: modelData.id !== undefined; onTapped: panel.inspect(modelData.id) }
        }
      }
      Controls.Label {
        anchors.centerIn: parent; visible: !grid.count
        text: panel.cards.length ? "没有符合条件的牌" : "弃牌堆为空"
      }
    }
  }
}
