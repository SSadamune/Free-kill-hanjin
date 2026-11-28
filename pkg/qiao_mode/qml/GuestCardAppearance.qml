// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Item {
  id: root
  required property Item card
  required property var appearance
  property bool inRoom: false
  anchors.fill: parent
  readonly property var model: card.dataModel
  readonly property var visibleFactions: model?.known ? appearance?.guestFactions ?? [] : []
  readonly property var picture: model?.known ? appearance?.picture : undefined

  Binding {
    target: root.card
    property: "cardFrontSource"
    value: root.picture ?? root.model?.frontSkin ?? ""
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
    standalone: root.inRoom && !root.model?.detailed
    factions: standalone ? root.appearance?.factions ?? [] : root.visibleFactions
    visible: !!root.model?.known && (root.model.detailed || standalone)
  }
  Loader {
    anchors.fill: parent
    active: root.inRoom && root.visibleFactions.length > 0
    sourceComponent: GuestFactionBorder { factions: root.visibleFactions }
  }
}
