// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import LunarLtk
import LunarLtk.Pages
import "SkillReferenceLinks.js" as SkillLinks

GeneralsOverview {
  id: overview

  property GridView standardGrid: null
  property RowLayout toolbarRow: null
  property Popup generalDetailPopup: null
  property Loader generalDetailLoader: null
  readonly property var detailPage: generalDetailLoader?.item
  readonly property Loader skillLoader: SkillLinks.findChild(detailPage,
    child => child instanceof SwipeView)?.itemAt(0) ?? null
  readonly property bool showingGuests: guestToggle.checked && stat === 0
  readonly property var registeredGuests: showingGuests
    ? (Lua.ev('require("packages.qiao.pkg.qiao_mode.rules.guest_factions").guests') ?? ({})) : ({})
  readonly property var zhenshiRanks: JSON.parse(Lua.ev(
    'json.encode(require("packages.qiao.pkg.qiao_mode.general_overview").zhenshiRanks())') ?? "{}")

  function sortZhenshi() {
    const names = Array.from(generals ?? []);
    if (!names.length || !names.every(name => zhenshiRanks[name] > 0)) return;
    const sorted = names.slice().sort((first, second) => zhenshiRanks[first] - zhenshiRanks[second]);
    if (sorted.some((name, index) => name !== names[index])) generals = sorted;
  }

  onGeneralsChanged: sortZhenshi()

  function placeGuestToggle() {
    if (!toolbarRow) return;
    const controls = Array.from(toolbarRow.children);
    const revert = controls.find(child => child instanceof ToolButton && child.text === Lua.tr("Revert Selection"));
    const current = controls.indexOf(guestToggle);
    if (!revert || current < 0 || controls[current + 1] === revert) return;
    controls.splice(current, 1);
    controls.splice(controls.indexOf(revert), 0, guestToggle);
    toolbarRow.children = controls;
  }

  Component.onCompleted: {
    // The registered overview does not expose its toolbar or card grid.
    const bar = children.find(child => child instanceof ToolBar);
    toolbarRow = bar?.contentItem.children.find(child => child instanceof RowLayout) ?? null;
    Qt.callLater(placeGuestToggle);
    standardGrid = children.find(child => child instanceof GridView) ?? null;
    guestPresentation.watch(standardGrid);
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

  onDetailPageChanged: guestPresentation.watch(detailPage)

  GeneralCardPresentation {
    id: guestPresentation
    enabledInContext: overview.showingGuests
    factions: overview.registeredGuests
    onlyRegistered: true
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
    visible: !!overview.toolbarRow && !!overview.standardGrid
    enabled: overview.stat === 0
    checkable: true
    text: Lua.tr("qiao_guest_illustrations")
    font.pixelSize: 20
  }

}
