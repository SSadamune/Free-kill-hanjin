// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk

QtObject {
  id: root

  required property Repeater cards
  required property var eligible

  function attach(card) {
    if (card && !card.children.some(child => child.objectName === "qiaoAscensionBadge")) {
      badge.createObject(card, { card });
    }
  }

  Component.onCompleted: {
    for (let i = 0; i < cards.count; ++i) attach(cards.itemAt(i));
  }

  readonly property Connections cardChanges: Connections {
    target: root.cards
    function onItemAdded(index, item) { root.attach(item); }
  }

  readonly property Component badge: Component {
    Rectangle {
      id: hint
      objectName: "qiaoAscensionBadge"
      required property Item card

      anchors.right: parent.right
      anchors.rightMargin: 4
      y: 45
      z: 2
      visible: !!hint.card.dataModel && root.eligible[hint.card.dataModel.name] === true
      width: label.implicitWidth + 10
      height: label.implicitHeight + 4
      radius: height / 2
      color: "#263b58"
      border.color: "#d6dbeb"

      Text {
        id: label
        anchors.centerIn: parent
        text: Lua.tr("qiao_selection_can_ascend")
        color: "#fff5dc"
        font.pixelSize: 12
        font.bold: true
      }
    }
  }
}
