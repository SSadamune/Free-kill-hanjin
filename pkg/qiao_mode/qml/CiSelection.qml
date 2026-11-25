// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk

Item {
  id: root
  property list<string> cardNames
  property string selection: ""
  property Item picker: null
  readonly property var scene: Ltk.roomScene

  width: button.width
  height: button.height

  function clicked() {
    if (!scene || !cardNames.length) return;
    scene.showInfoPopup(pile, {
      name: "qiao__ci_consume",
      cardNames: Array.from(cardNames),
      selectedCi: selection,
      chooseCard: name => {
        selection = name;
        Lua.updateRequestUI("Interaction", "1", "update", name);
        scene.closeInfoPopup();
      },
    });
    picker = scene.infoPopup.item;
  }

  function clear() {
    if (picker && scene?.infoPopup.item === picker) scene.closeInfoPopup();
    picker = null;
  }

  Component { id: pile; CiPile {} }

  MetroButton {
    id: button
    text: root.selection ? Lua.tr(root.selection) : Lua.tr("qiao__ci_select")
    onClicked: root.clicked()
  }
}
