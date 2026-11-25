// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import LunarLtk
import LunarLtk.Pages
import "GuestIllustration.js" as GuestIllustration
import "SkillReferenceLinks.js" as SkillLinks

GeneralsOverview {
  id: overview

  property GridView standardGrid: null
  property ListView packageList: null
  property RowLayout toolbarRow: null
  property Popup generalDetailPopup: null
  property Loader generalDetailLoader: null
  readonly property var detailPage: generalDetailLoader?.item
  readonly property Loader skillLoader: SkillLinks.findChild(detailPage,
    child => child instanceof SwipeView)?.itemAt(0) ?? null
  readonly property string selectedPackage: packageList?.model[packageList.currentIndex] ?? ""
  readonly property bool showingGuests: guestToggle.checked && stat === 0
  readonly property var registeredGuests: {
    if (!showingGuests || !selectedPackage) return ({});
    return Lua.ev(`require("packages.qiao.pkg.qiao_mode.rules.guest_factions").registeredInPackage(${JSON.stringify(selectedPackage)})`) ?? ({});
  }

  Component.onCompleted: {
    // The registered overview does not expose its toolbar or package selector.
    const bar = children.find(child => child instanceof ToolBar);
    toolbarRow = bar?.contentItem.children.find(child => child instanceof RowLayout) ?? null;
    packageList = children.find(child => child instanceof ListView
      && typeof child.model?.get !== "function") ?? null;
    standardGrid = children.find(child => child instanceof GridView && child !== guestGrid) ?? null;
    // The native overview exposes the skill tab as the first loader in the
    // detail page, but keeps the surrounding popup and its loader private.
    for (const item of data) {
      if (!(item instanceof Popup)) continue;
      const loader = SkillLinks.findChild(item.contentItem, child => (
        child instanceof Loader && /(^|\/)GeneralDetailPage\.qml$/.test(String(child.source))
      ));
      if (!loader) continue;
      generalDetailPopup = item;
      generalDetailLoader = loader;
      break;
    }
  }

  Binding {
    target: overview.skillLoader
    property: "sourceComponent"
    value: linkedSkillTab
    when: !!overview.skillLoader && !!overview.detailPage?.general
      && Ltk.getGeneralData(overview.detailPage.general).extension === "qiao"
  }

  Component {
    id: linkedSkillTab

    Flickable {
      id: skillViewport
      clip: true
      contentHeight: skillPane.height
      ScrollBar.vertical: ScrollBar {}

      // The overview calls update() on the active tab after a general change.
      // The linked view reads the general directly through its bindings.
      function update() {}

      SkillReferencePane {
        id: skillPane
        viewport: skillViewport
        width: skillViewport.width - 4
        x: 2
        active: visible && overview.visible && overview.generalDetailPopup.visible
        referenceKey: overview.detailPage?.general ?? ""
        textColor: "#292620"
        darkBackground: false
        rootText: (catalog, theme) => {
          const name = skillPane.referenceKey;
          const groups = name ? [{ name, detail: Ltk.getGeneralDetail(name) }] : [];
          return SkillLinks.generalText(catalog, theme, groups, key => Lua.tr(key), false);
        }
      }
    }
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
      return names.filter(name => overview.registeredGuests[name]?.length > 0);
    }

    delegate: Item {
      id: tile
      required property string modelData
      readonly property var factions: Array.from(overview.registeredGuests[modelData] ?? [])
      width: guestGrid.cellWidth
      height: guestGrid.cellHeight

      Component.onCompleted: {
        // Reuse the original card delegate, including its detail and ban-list UI.
        if (factions.length === 0) return;
        const card = overview.standardGrid.delegate.createObject(this, { modelData });
        if (!card) return;
        card.dataModel.kingdom = factions[0];
        card.dataModel.subkingdom = factions[1] ?? "";
        const picture = GuestIllustration.picture(modelData, true);
        if (picture) card.cardFrontSource = picture;
        factionBadges.card = card;
      }

      GuestFactionBadges {
        id: factionBadges
        factions: tile.factions
        z: 1
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
