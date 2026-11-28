// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Item {
  id: layout
  objectName: "qiaoDualMountRow"
  required property Item defensiveItem
  required property Item offensiveItem
  required property var isDualMount
  required property var distanceLabels

  function occupiesBoth(item) {
    const cards = item.equips;
    return cards.length > 0 && isDualMount(cards[cards.length - 1].name);
  }

  readonly property bool defensiveFull: occupiesBoth(defensiveItem)
  readonly property bool offensiveFull: occupiesBoth(offensiveItem)
  readonly property Item row: defensiveItem.parent.parent

  Binding {
    target: layout.defensiveItem.parent
    property: "width"
    value: layout.defensiveFull ? layout.row.width : 0
    when: layout.defensiveFull || layout.offensiveFull
  }
  Binding {
    target: layout.offensiveItem.parent
    property: "width"
    value: layout.offensiveFull ? layout.row.width : 0
    when: layout.defensiveFull || layout.offensiveFull
  }
  Binding {
    target: layout.defensiveItem.parent
    property: "visible"
    value: false
    when: layout.offensiveFull
  }
  Binding {
    target: layout.offensiveItem.parent
    property: "visible"
    value: false
    when: layout.defensiveFull
  }

  EquipSlotLabel {
    slot: layout.defensiveItem
    dualMount: layout.defensiveFull
    distance: layout.distanceLabels[card?.cardId] ?? ""
  }
  EquipSlotLabel {
    slot: layout.offensiveItem
    dualMount: layout.offensiveFull
    distance: layout.distanceLabels[card?.cardId] ?? ""
  }
}
