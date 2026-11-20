// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Pages.InfoPopups

ViewGeneralPile {
  id: root

  required property int holderId
  readonly property var scene: Ltk.roomScene
  readonly property bool isHolder: !Config.observing && !Config.replaying && Cpp.self.id === holderId

  function canConsume() {
    return Lua.ev(`ClientInstance:canConsumeCi(${holderId})`);
  }

  MetroButton {
    Layout.alignment: Qt.AlignHCenter
    text: Lua.tr("qiao__ci_consume")
    visible: root.isHolder
    enabled: visible && root.cardNames.length > 0 && root.scene?.progress.visible && root.canConsume()

    onClicked: {
      if (!root.canConsume()) return;
      root.scene.closeInfoPopup();
      Lua.updateRequestUI("QiaoCi", root.holderId, "click", {});
    }
  }
}
