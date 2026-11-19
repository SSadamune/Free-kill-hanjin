// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk
import LunarLtk.Pages

Room {
  id: room

  Component {
    id: mountRow
    DualMountRow {}
  }

  function bindMountRows() {
    for (let i = 0; i < photoModel.count; ++i) {
      const area = photoModel.get(i).modelData.photoItem?.areasSealed;
      if (!area || area.children.some(child => child.objectName === "qiaoDualMountRow"))
        continue;
      const defensive = area.items[area.subtypes.indexOf("defensive_ride")];
      const offensive = area.items[area.subtypes.indexOf("offensive_ride")];
      if (defensive && offensive) {
        mountRow.createObject(area, {
          defensiveItem: defensive,
          offensiveItem: offensive,
          isDualMount: name => Lua.evaluate(`Fk.packages.qiao_cards.qiao.isDualMount(${JSON.stringify(name)})`),
        });
      }
    }
  }

  Connections {
    target: room.photoModel
    function onModelDataChanged() { Qt.callLater(room.bindMountRows); }
  }

  Connections {
    target: room.dataModel
    function onCardsMoved() { Qt.callLater(room.bindMountRows); }
  }

  Component.onCompleted: Qt.callLater(bindMountRows)
}
