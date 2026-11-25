// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import LunarLtk
import LunarLtk.Components

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
  width: Math.min(720, parent.width - 24)
  height: Math.min(462, parent.height - 24)
  x: Math.round((parent.width - width) / 2)
  y: Math.round((parent.height - height) / 2)
  padding: 12
  focus: true
  onOpened: refresh()
  onClosed: { search.clear(); onlyLord.checked = false; grid.positionViewAtBeginning(); }

  background: Rectangle {
    color: "#f02a221c"
    border.color: "#9a7754"
    radius: 8
  }

  contentItem: ColumnLayout {
    spacing: 6
    RowLayout {
      Layout.fillWidth: true
      Controls.Label {
        Layout.fillWidth: true
        text: "弃牌堆  ·  " + panel.cards.length + " 张"
        color: "#fff0d1"
        font.bold: true
        font.pixelSize: 18
      }
      Controls.Button { text: "关闭"; onClicked: panel.close() }
    }
    RowLayout {
      Layout.fillWidth: true
      Controls.TextField { id: search; objectName: "discardSearch"; placeholderText: "搜索牌名"; Layout.fillWidth: true }
      Controls.CheckBox {
        id: onlyLord
        objectName: "lordFilter"
        text: "仅君主装备"
        palette.windowText: "#fff0d1"
      }
    }
    GridView {
      id: grid; objectName: "discardGrid"
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      cellWidth: width / Math.max(1, Math.floor(width / 108))
      cellHeight: 174
      model: panel.filtered
      Controls.ScrollBar.vertical: Controls.ScrollBar {}
      delegate: Item {
        id: slot
        required property var modelData
        readonly property bool faceUp: typeof modelData.id === "number"
        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
          anchors.fill: parent
          anchors.margins: 3
          radius: 5
          color: hover.hovered ? "#514230" : slot.modelData.lord ? "#493626" : "transparent"
          border.color: slot.modelData.lord ? "#b58a52" : "transparent"
        }
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 6
          width: parent.width - 12
          spacing: 2

          CardItem {
            objectName: "discardCardFace"
            anchors.horizontalCenter: parent.horizontalCenter
            cardScale: Math.min(1, parent.width / 93)
            enabled: false
            showDetail: false
            dataModel: slot.faceUp
              ? Ltk.createCardModel(slot.modelData.id, { selectable: true })
              : coveredCard

            CardModel { id: coveredCard; known: false; selectable: true }
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: slot.faceUp ? slot.modelData.name : "未知牌"
            color: slot.modelData.lord ? "#ffe0a4" : "#fff0d1"
            font.pixelSize: 15
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: [slot.modelData.lord ? "君主装备" : "", slot.modelData.marks].filter(Boolean).join(" · ")
            color: "#d9b98b"
            font.pixelSize: 12
          }
        }
        HoverHandler { id: hover; enabled: slot.faceUp; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: slot.faceUp; onTapped: panel.inspect(slot.modelData.id) }
      }
      Controls.Label {
        anchors.centerIn: parent
        visible: !grid.count
        color: "#d9b98b"
        text: panel.cards.length ? "没有符合条件的牌" : "弃牌堆为空"
      }
    }
  }
}
