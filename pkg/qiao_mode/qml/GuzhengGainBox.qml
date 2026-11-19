// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQml.Models
import LunarLtk
import LunarLtk.Models.Popups
import LunarLtk.Pages.Popups

PoxiBox {
  id: root

  required property var cards
  required property int maxGain
  property bool initialSelectionApplied: false

  dataModel: PoxiModel {
    poxiType: "AskForCardsChosen"
    cardData: [["弃牌堆", root.cards]]
    cancelable: false
    extraData: ({ min: 0, max: root.maxGain, prompt: "#qiao__skill_wu015a_2-gain" })
    onAccepted: {
      if (root.initialSelectionApplied && feasible) Ltk.roomModel.replyToServer(selectedIds.slice())
    }
  }

  function applyInitialSelection() {
    if (initialSelectionApplied) return;
    const models = dataModel.cardModels;
    if (cards.some(cid => !models[cid].cardItem)) return;
    initialSelectionApplied = true;
    for (const cid of cards) models[cid].selected = true;
  }

  // The native list creates its card delegates after the popup itself.
  Instantiator {
    model: root.cards
    delegate: Connections {
      required property int modelData
      target: root.dataModel.cardModels[modelData]
      function onCardItemChanged() { Qt.callLater(root.applyInitialSelection); }
    }
  }

  Component.onCompleted: Qt.callLater(applyInitialSelection)
}
