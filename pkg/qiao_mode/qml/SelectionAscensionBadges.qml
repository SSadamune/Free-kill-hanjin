// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk

QtObject {
  id: root

  required property Repeater cards
  required property var eligible
  property var loyaltyEligible: ({})

  function attach(card) {
    if (card && !card.children.some(child => child.objectName === "qiaoSelectionBadges")) {
      badges.createObject(card, { card });
    }
  }

  Component.onCompleted: {
    for (let i = 0; i < cards.count; ++i) attach(cards.itemAt(i));
  }

  readonly property Connections cardChanges: Connections {
    target: root.cards
    function onItemAdded(index, item) { root.attach(item); }
  }

  readonly property Component badges: Component {
    Column {
      id: tags
      objectName: "qiaoSelectionBadges"
      required property Item card
      readonly property Item nativeCompanion: card.children.find(child => child instanceof Image
        && /-companions(?:\.png)?$/i.test(child.source.toString())) ?? null

      anchors.right: parent.right
      anchors.rightMargin: 1
      anchors.bottom: parent.bottom
      // Leave 16 pixels for the package badge and a 2-pixel gap.
      anchors.bottomMargin: 18
      z: 2
      spacing: 2

      Binding {
        target: tags.nativeCompanion
        property: "visible"
        when: tags.nativeCompanion !== null
        value: false
      }

      SelectionBadge {
        objectName: "qiaoAscensionBadge"
        caption: Lua.tr(root.loyaltyEligible[tags.card.dataModel?.name] === true
          ? "qiao_selection_can_pledge_loyalty" : "qiao_selection_can_ascend")
        visible: root.eligible[tags.card.dataModel?.name] === true
      }

      SelectionBadge {
        objectName: "qiaoCompanionBadge"
        caption: Lua.tr("Companions")
        visible: tags.card.dataModel?.hasCompanion ?? false
      }
    }
  }

  component SelectionBadge: Rectangle {
    id: badge
    required property string caption
    anchors.right: parent.right
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
      text: badge.caption
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
