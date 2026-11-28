// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk
import LunarLtk

Item {
  id: root
  objectName: "qiaoEquipSlotLabel"
  required property Item slot
  property string distance: ""
  property bool dualMount: false

  // EquipItem 的牌名是直接 Text 子项，点数用另一个组件画。
  readonly property Text label: slot.children.find(child => child instanceof Text) ?? null
  readonly property Image icon: slot.children.find(child => child instanceof Image) ?? null
  readonly property var card: slot.equips[slot.equips.length - 1]
  readonly property bool yu: card?.marks.some(mark => mark.origName === "@qiao_bajia_yu") ?? false
  readonly property bool active: label !== null && !!card && (yu || distance !== "")
  readonly property bool compactYu: active && yu && !dualMount && slot.subtype.endsWith("_ride") && icon !== null
  readonly property string cardLabel: {
    if (!card) return "";
    if (!distance) return Ltk.getCardUIName(card.cardId, true);
    return dualMount ? distance + " " + Lua.tr(card.name) : distance;
  }

  Binding {
    target: root.label
    property: "text"
    when: root.active
    value: (root.yu ? "[" + Lua.tr("qiao_bajia_yu") + "]" : "") + root.cardLabel
  }
  // 半栏坐骑用通用马图标的位置容纳前缀，保留右侧点数和花色。
  Binding {
    target: root.icon
    property: "visible"
    when: root.compactYu
    value: false
  }
  Binding {
    target: root.label?.anchors ?? null
    property: "leftMargin"
    when: root.compactYu
    value: 1 - (root.icon?.x ?? 0) - (root.icon?.width ?? 0)
  }
  Binding {
    target: root.label
    property: "scale"
    when: root.active && root.yu
    value: Math.min(1, (root.label?.width ?? 0) / Math.max(1, root.label?.contentWidth ?? 0))
  }
  Binding {
    target: root.label
    property: "transformOrigin"
    when: root.active && root.yu
    value: Item.Left
  }
  Binding {
    target: root.label
    property: "width"
    when: root.active
    value: Math.max(0, root.slot.width - (root.label?.x ?? 0) - 24)
  }
  Binding {
    target: root.label
    property: "fontSizeMode"
    when: root.active && !root.yu
    value: Text.HorizontalFit
  }
  Binding {
    target: root.label
    property: "minimumPixelSize"
    when: root.active && !root.yu
    value: 9
  }
}
