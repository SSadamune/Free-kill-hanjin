// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Components.Common
import LunarLtk.Pages.InfoPopups

ViewPile {
  id: root

  name: "qiao__skill_em_han001_banner"
  required property int holderId
  property var actions: ({})
  signal requested(string action)

  Row {
    Layout.alignment: Qt.AlignHCenter
    visible: !!root.actions.selecting
    spacing: 8

    MetroButton {
      text: Lua.tr(root.actions.maxCards === 2 ? "qiao__edict_place_two" : "qiao__edict_place_one")
      enabled: !!root.actions.canPlace
      onClicked: root.requested("place")
    }
    MetroButton {
      text: Lua.tr("qiao__edict_take_trick")
      visible: !!root.actions.showTake
      enabled: !!root.actions.canTake
      onClicked: root.requested("take")
    }
    MetroButton {
      text: Lua.tr("Cancel")
      onClicked: root.requested("cancel")
    }
  }
}
