// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import Fk
import LunarLtk
import "SkillReferenceLinks.js" as Links

Column {
  id: root
  objectName: "qiaoSkillReferencePane"

  required property Flickable viewport
  required property var rootText
  property bool active: visible
  property bool inlineTips: false
  property var generalCardPresentation: null
  property string referenceKey
  property color textColor: "#E4D5A0"
  property bool darkBackground: true
  readonly property var theme: darkBackground
    ? { page: "#9ED9FC", tip: "#A9E7C7" } : { page: "#205D95", tip: "#16664C" }

  property var pages: []
  property var currentPage: null
  property var tips: []
  property point linkPosition
  readonly property var catalog: Links.createCatalog(
    JSON.parse(Lua.ev('json.encode(require("packages.qiao.pkg.qiao_mode.skill_references").catalog())')))

  spacing: 6
  onActiveChanged: if (!active) closeTips()
  onReferenceKeyChanged: reset()

  function reset() {
    closeTips();
    pages = [];
    currentPage = null;
  }

  function closeTips() {
    const opened = tips;
    tips = [];
    for (let i = opened.length - 1; i >= 0; --i) opened[i].close();
  }

  function tipClosed(tip) {
    const index = tips.indexOf(tip);
    if (index === -1) return;
    const descendants = tips.slice(index + 1);
    tips = tips.slice(0, index);
    for (let i = descendants.length - 1; i >= 0; --i) descendants[i].close();
  }

  function showPage(page) {
    closeTips();
    pages = [...pages, { page: currentPage, y: viewport.contentY }];
    currentPage = page;
    viewport.contentY = 0;
  }

  function goBack() {
    if (pages.length === 0) return;
    closeTips();
    const previous = pages[pages.length - 1];
    pages = pages.slice(0, -1);
    currentPage = previous.page;
    Qt.callLater(() => {
      const lastY = Math.max(0, viewport.contentHeight - viewport.height);
      viewport.contentY = Math.max(0, Math.min(previous.y, lastY));
    });
  }

  function showTip(entries, position) {
    if (!entries.length) return;
    const tip = tooltip.createObject(root, { entries, linkPosition: position });
    if (!tip) return;
    tips = [...tips, tip];
    tip.open();
  }

  function activate(link, position) {
    if (!active) return;
    const [type, encodedName, encodedSource] = link.split(":");
    if (type === "qiao-card") {
      const name = decodeURIComponent(encodedName);
      const entries = catalog.variants[name] ?? (catalog.cards[name] ? [catalog.cards[name]] : []);
      showTip(entries, position);
    } else if (type === "qiao-page" || type === "qiao-tip") {
      const page = type === "qiao-page";
      const entries = Links.lookup(catalog, decodeURIComponent(encodedName), decodeURIComponent(encodedSource), page);
      if (page && entries.length) showPage(entries);
      if (!page) showTip(entries, position);
    } else {
      const entry = catalog.skills.get(link) ?? catalog.skills.get(link.replace(/^:/, ""));
      if (entry?.page) {
        showPage([entry]);
      } else {
        const body = Lua.tr(link);
        if (entry || body !== link) showTip([entry ?? { id: link, description: body }], position);
      }
    }
  }

  function pageText(entries) {
    return entries.map(entry => {
      if (entry.page === "banner") return Links.entriesText(catalog, theme, [entry]);
      const title = entries.length > 1 && entry.variant ? entry.variant + " " + entry.title : entry.title;
      const factions = generalCardPresentation?.appearanceFor(entry.id).factions;
      const groups = [{ name: entry.id, title, detail: Ltk.getGeneralDetail(entry.id), factions }];
      return Links.generalText(catalog, theme, groups, name => Lua.tr(name), true);
    }).join("<br/><br/>");
  }

  Button {
    objectName: "qiaoSkillReferenceBack"
    visible: root.pages.length > 0
    text: Lua.hasTranslate("qiao_skill_reference_back") ? Lua.tr("qiao_skill_reference_back") : Lua.tr("Back")
    onClicked: root.goBack()
  }

  TextEdit {
    id: description
    objectName: "qiaoSkillReferenceDescription"
    width: root.width
    readOnly: true
    selectByKeyboard: true
    selectByMouse: false
    wrapMode: TextEdit.WordWrap
    textFormat: TextEdit.RichText
    font.pixelSize: 18
    color: root.textColor
    text: root.currentPage ? root.pageText(root.currentPage) : root.rootText(root.catalog, root.theme)
    onLinkActivated: link => root.activate(link, root.linkPosition)

    TapHandler {
      onPressedChanged: {
        if (pressed) root.linkPosition = description.mapToItem(root.viewport, point.position);
      }
    }
  }

  Component {
    id: tooltip
    SkillReferenceTooltip {
      id: tip
      parent: root.viewport
      viewport: root.viewport
      modal: !root.inlineTips
      transformOrigin: root.inlineTips ? Popup.TopLeft : Popup.Center
      scale: {
        if (!root.inlineTips) return 1;
        // Popup is reparented to the window overlay. Match the viewport's scale.
        const step = Config.winScale;
        const left = root.viewport.mapToItem(null, 0, 0);
        const right = root.viewport.mapToItem(null, step, 0);
        return (right.x - left.x) / step;
      }
      dismissOnOutsideClick: root.tips[root.tips.length - 1] === tip
      html: Links.entriesText(root.catalog, { page: "#9ED9FC", tip: "#A9E7C7" }, entries)
      onReferenceClicked: (link, position) => root.activate(link, position)
      onClosed: {
        root.tipClosed(tip);
        tip.destroy();
      }
    }
  }
}
