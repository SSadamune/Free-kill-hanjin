// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQml.Models
import Fk

Item {
  id: badges

  required property var factions
  property Item card: null
  readonly property bool clustered: factions.length >= 3
  readonly property int badgeSize: 22
  readonly property int columnStep: 18
  readonly property int rowStep: 15
  readonly property int topCount: Math.floor(factions.length / 2)
  readonly property int topOffset: factions.length % 2 ? columnStep / 2 : 0
  readonly property int bottomOffset: factions.length % 2 ? 0 : 6

  x: 2
  y: 2
  height: rowStep + badgeSize

  readonly property var stockParts: {
    // The stock card exposes its model, but not its two faction images or label positions.
    if (!card) return [];
    const parts = [];
    for (const child of card.children) {
      if (child instanceof Image && child.width === 34) {
        parts.push({ item: child, property: "visible", role: "badge" });
      } else if (child instanceof Row) {
        parts.push({ item: child, property: "x", role: "hp" });
      } else if (child instanceof Text && child.wrapMode === Text.WrapAnywhere) {
        parts.push({ item: child, property: "y", role: "name" });
      }
    }
    return parts;
  }

  Instantiator {
    model: badges.stockParts
    delegate: Binding {
      required property var modelData
      target: modelData.item
      property: modelData.property
      when: badges.clustered
      value: {
        switch (modelData.role) {
          case "badge": return false;
          case "hp": return badges.x + badges.topOffset + (badges.topCount - 1) * badges.columnStep + badges.badgeSize + 3;
          case "name": return badges.y + badges.height + 1;
        }
      }
    }
  }

  Repeater {
    model: badges.clustered ? badges.factions : []

    Image {
      required property int index
      required property string modelData
      x: index < badges.topCount ? badges.topOffset + index * badges.columnStep
        : badges.bottomOffset + (index - badges.topCount) * badges.columnStep
      y: index < badges.topCount ? 0 : badges.rowStep
      width: badges.badgeSize
      height: badges.badgeSize
      fillMode: Image.PreserveAspectFit
      source: SkinBank.getGeneralCardDir(modelData) + modelData
    }
  }
}
