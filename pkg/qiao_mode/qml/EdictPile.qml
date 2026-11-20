// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Pages.InfoPopups

ViewPile {
  id: root

  required property int holderId
  readonly property var scene: Ltk.roomScene
  readonly property bool isHolder: !Config.observing && !Config.replaying && Cpp.self.id === holderId

  function canTakeTrick() {
    return Lua.ev(`ClientInstance:canConsumeEdict(${holderId})`);
  }

  MetroButton {
    Layout.alignment: Qt.AlignHCenter
    text: Lua.tr("qiao__edict_take_trick")
    visible: root.isHolder
    enabled: {
      // The Lua query itself has no QML change signal.
      root.scene?.pileActionRevision;
      return visible && root.scene?.progress.visible && root.canTakeTrick();
    }

    onClicked: {
      if (!root.canTakeTrick()) return;
      root.scene.closeInfoPopup();
      Lua.updateRequestUI("QiaoEdict", root.holderId, "click", {});
    }
  }
}
