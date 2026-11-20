// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk

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

  // EquipItem 的直接 Text 子项是牌名；点数由独立的 GlowText 组件显示。
  component MountLabel: QtObject {
    required property Item slot
    required property bool dual
    readonly property Text equipLabel: slot.children.find(child => child instanceof Text) ?? null
    readonly property var card: slot.equips[slot.equips.length - 1]
    readonly property string distance: layout.distanceLabels[card?.cardId] ?? ""
    readonly property bool active: equipLabel !== null && distance !== ""

    property Binding displayText: Binding {
      target: equipLabel
      property: "text"
      when: active
      value: dual && card ? distance + " " + Lua.tr(card.name) : distance
    }
    property Binding labelWidth: Binding {
      target: equipLabel
      property: "width"
      when: active
      value: Math.max(0, slot.width - (equipLabel?.x ?? 0) - 24)
    }
    property Binding fontFit: Binding {
      target: equipLabel
      property: "fontSizeMode"
      when: active
      value: Text.HorizontalFit
    }
    property Binding fontMinimum: Binding {
      target: equipLabel
      property: "minimumPixelSize"
      when: active
      value: 9
    }
  }

  MountLabel {
    slot: layout.defensiveItem
    dual: layout.defensiveFull
  }
  MountLabel {
    slot: layout.offensiveItem
    dual: layout.offensiveFull
  }
}
