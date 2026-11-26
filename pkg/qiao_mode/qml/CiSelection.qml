// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk

Item {
  id: root
  property list<string> cardNames
  property var actionsByCard
  property Item picker: null
  readonly property var scene: Ltk.roomScene

  width: button.width
  height: button.height

  function clicked() {
    if (!scene || !cardNames.length || picker) return;
    scene.showInfoPopup(pile, {
      mode: "consume",
      prompt: "#qiao__jin001_banner-active",
      cardNames: Array.from(cardNames),
      actionsByCard,
    });
    picker = scene.infoPopup.item;
  }

  function clear() {
    const opened = picker;
    picker = null;
    if (opened && scene?.infoPopup.item === opened) scene.closeInfoPopup();
  }

  function submit(action, choice) {
    clear();
    Lua.updateRequestUI("Interaction", "1", action, choice);
  }

  Connections {
    target: root.scene?.infoPopup ?? null
    function onClosed() {
      if (!root.picker) return;
      root.picker = null;
      Lua.updateRequestUI("Interaction", "1", "cancel", "");
    }
  }

  Component {
    id: pile
    CiPile {
      onSubmitted: choice => root.submit("finish", choice)
      onCanceled: root.submit("cancel", "")
    }
  }

  MetroButton {
    id: button
    text: Lua.tr("qiao__ci_consume")
    onClicked: root.clicked()
  }
}
