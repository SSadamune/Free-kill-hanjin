// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "GuestIllustration.js" as GuestIllustration

Item {
  id: root
  required property Item card
  required property bool enabledInContext
  readonly property var model: card.dataModel
  property var factions: []
  readonly property var visibleFactions: enabledInContext && model?.known ? factions : []
  readonly property var picture: model?.known
    ? GuestIllustration.picture(model.name, enabledInContext) : undefined

  Binding {
    target: root.card
    property: "cardFrontSource"
    // The selection box reuses its card item when the general changes.
    value: root.picture || root.model?.frontSkin || ""
  }
  Binding {
    target: root.model
    property: "kingdom"
    when: root.visibleFactions.length > 0
    value: root.visibleFactions[0] ?? ""
  }
  Binding {
    target: root.model
    property: "subkingdom"
    when: root.visibleFactions.length > 0
    value: root.visibleFactions[1] ?? ""
  }
  GuestFactionBadges {
    card: root.card
    factions: root.visibleFactions
    visible: root.model?.detailed ?? false
  }
}
