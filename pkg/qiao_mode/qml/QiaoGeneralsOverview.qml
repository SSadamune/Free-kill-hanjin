// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import LunarLtk.Pages
import "GuestIllustration.js" as GuestIllustration

GeneralsOverview {
  id: overview

  property GridView standardGrid: null
  property ListView packageList: null
  property RowLayout toolbarRow: null
  readonly property string selectedPackage: packageList?.model[packageList.currentIndex] ?? ""
  readonly property bool showingGuests: guestToggle.checked && stat === 0
  readonly property var registeredGuests: {
    if (!showingGuests || !selectedPackage) return [];
    const names = Lua.ev(`require("packages.qiao.pkg.qiao_mode.rules.guest_factions").registeredInPackage(${JSON.stringify(selectedPackage)})`);
    return Array.from(names ?? []);
  }

  Component.onCompleted: {
    // The registered overview does not expose its toolbar or package selector.
    const bar = children.find(child => child instanceof ToolBar);
    toolbarRow = bar?.contentItem.children.find(child => child instanceof RowLayout) ?? null;
    packageList = children.find(child => child instanceof ListView
      && typeof child.model?.get !== "function") ?? null;
    standardGrid = children.find(child => child instanceof GridView && child !== guestGrid) ?? null;
  }

  ToolButton {
    id: guestToggle
    parent: overview.toolbarRow
    visible: !!overview.toolbarRow && !!overview.packageList && !!overview.standardGrid
    enabled: overview.stat === 0 && overview.selectedPackage !== ""
    checkable: true
    text: Lua.tr("qiao_guest_illustrations")
    font.pixelSize: 20
  }

  Binding {
    target: overview.standardGrid
    property: "visible"
    value: false
    when: overview.showingGuests && !!overview.standardGrid
  }

  GridView {
    id: guestGrid
    visible: overview.showingGuests
    anchors.fill: overview.standardGrid
    opacity: overview.standardGrid?.opacity ?? 1
    cellWidth: overview.standardGrid?.cellWidth ?? 100
    cellHeight: overview.standardGrid?.cellHeight ?? 140
    clip: true
    model: {
      const names = Array.from(overview.standardGrid?.model ?? []);
      return names.filter(name => overview.registeredGuests.includes(name));
    }

    delegate: Item {
      required property string modelData
      width: guestGrid.cellWidth
      height: guestGrid.cellHeight

      Component.onCompleted: {
        // Reuse the original card delegate, including its detail and ban-list UI.
        const card = overview.standardGrid.delegate.createObject(this, { modelData });
        const picture = GuestIllustration.picture(modelData, true);
        if (card && picture) card.cardFrontSource = picture;
      }
    }

    footer: Label {
      width: guestGrid.width
      height: 40
      text: "共" + guestGrid.count + "个武将"
      font.pixelSize: 20
      horizontalAlignment: Text.AlignHCenter
      font.family: Config.libianName
      color: "lightgrey"
    }
  }
}
