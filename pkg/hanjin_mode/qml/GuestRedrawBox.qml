// SPDX-License-Identifier: GPL-3.0-or-later
//
// Voluntary 客将 re-draw box. Only candidates whose this-game faction came from
// a guest faction are selectable. Each card shows the resolved factions for the
// current room, which can differ from the printed ones on the card.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components
import LunarLtk.Pages.Popups

GraphicsBox {
  id: root

  property var generals: []
  property var factions: ({})
  property var guests: []
  property int maxSelect: 0
  property string prompt: ""
  property var selectedItem: []

  title.text: Ltk.processPrompt(prompt)
  width: 780
  height: 440

  onShown: updateSelectable()

  function isGuest(name) {
    return guests.indexOf(name) !== -1;
  }

  function updateSelectable() {
    for (let i = 0; i < generalRepeater.count; i++) {
      const item = generalRepeater.itemAt(i);
      if (!item) continue;
      item.selectable = isGuest(item.modelData) && selectedItem.length < maxSelect
        || selectedItem.indexOf(item.modelData) !== -1;
    }
    confirmButton.enabled = selectedItem.length <= maxSelect;
  }

  Flickable {
    id: cardArea
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 45
    anchors.bottom: buttonArea.top
    anchors.bottomMargin: 10
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    clip: true
    contentHeight: generalFlow.height

    Flow {
      id: generalFlow
      width: parent.width
      spacing: 8

      Repeater {
        id: generalRepeater
        model: root.generals

        GeneralCardItem {
          required property string modelData
          required property int index
          property var entry: root.factions[modelData] || ({ kingdoms: [], source: "" })
          dataModel: Ltk.createGeneralCardModel(modelData)
          selectable: root.isGuest(modelData)
          chosenInBox: root.selectedItem.indexOf(modelData) !== -1

          onClicked: {
            const name = modelData;
            if (!root.isGuest(name)) return;
            const at = root.selectedItem.indexOf(name);
            if (at !== -1) {
              root.selectedItem.splice(at, 1);
            } else if (root.selectedItem.length < root.maxSelect) {
              root.selectedItem.push(name);
            }
            // Replace the array so QML bindings on chosenInBox re-evaluate.
            root.selectedItem = root.selectedItem.slice();
            root.updateSelectable();
          }

          // Resolved this-game factions. Kept separate from the printed icon
          // on the card so a guest entry is visible.
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 22
            color: "#CC1d1e19"
            visible: parent.entry.kingdoms.length > 0

            Row {
              anchors.centerIn: parent
              spacing: 2
              Repeater {
                model: parent.parent.parent.entry.kingdoms
                Image {
                  required property string modelData
                  width: 17
                  height: 17
                  source: SkinBank.getGeneralCardDir(modelData) + modelData
                }
              }
              Text {
                height: 18
                font.pixelSize: 12
                color: parent.parent.parent.entry.source === "guest" ? "#fdf142" : "white"
                text: parent.parent.parent.entry.source === "guest" ? "客" : ""
              }
            }
          }
        }
      }
    }
  }

  Row {
    id: buttonArea
    height: 40
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    spacing: 12

    MetroButton {
      id: confirmButton
      width: 120
      text: Lua.tr("OK")
      enabled: true
      onClicked: {
        root.close();
        Ltk.roomModel.deActivate();
        ClientInstance.replyToServer("", { indices: root.selectedItem });
      }
    }

    MetroButton {
      width: 120
      text: Lua.tr("Cancel")
      onClicked: {
        root.close();
        Ltk.roomModel.deActivate();
        ClientInstance.replyToServer("", { indices: [] });
      }
    }
  }
}
