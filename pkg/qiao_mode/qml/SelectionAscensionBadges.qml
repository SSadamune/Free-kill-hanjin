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
      anchors.rightMargin: 1
      anchors.bottom: parent.bottom
      // Native companion art begins at y=80 and crosses the lower corner.
      // Otherwise leave 16 pixels for the package badge and a 2-pixel gap.
      anchors.bottomMargin: card.dataModel?.hasCompanion ? card.height - 78 : 18
      z: 2
      visible: !!hint.card.dataModel && root.eligible[hint.card.dataModel.name] === true
      width: label.implicitWidth + 24
      height: 17
      color: "transparent"

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#001e1a15" }
        GradientStop { position: 0.42; color: "#a61e1a15" }
        GradientStop { position: 1; color: "#cf1e1a15" }
      }

      Text {
        id: label
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        text: Lua.tr("qiao_selection_can_ascend")
        color: "#ffe6b1"
        font.pixelSize: 11
        font.bold: true
      }

      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: parent.height - 4
        color: "#d9b477"
      }
    }
  }
}
