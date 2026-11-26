// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components as LtkComponents
import LunarLtk.Pages
import LunarLtk.Pages.InfoPopups as Info
import "GuestIllustration.js" as GuestIllustration
import "SkillReferenceLinks.js" as SkillLinks

Room {
  id: room
  property var mountDistanceLabels: ({})
  property bool guestIllustrations: false
  property int guestFactionsRevision: 0
  readonly property var guestCardFactions: {
    guestFactionsRevision;
    if (!guestIllustrations) return {};
    const factions = JSON.parse(Lua.ev("json.encode(ClientInstance:guestCardFactions())") ?? "{}");
    return Object.fromEntries(Object.entries(factions).map(([name, values]) =>
      [name, GuestIllustration.roomFactions(values)]));
  }
  property int pileActionRevision: 0
  property int ciRevision: 0
  property int ownHiddenGeneralsRevision: 0
  property int skillStatusRevision: 0
  property int discardCount: 0

  TextMetrics {
    id: choiceMetrics
    font.pixelSize: 20
    font.weight: Font.Medium
  }

  function showSingleChoice(sender, request) {
    const [choices, allChoices, limits, cancelable, skill, prompt, , single] = request;
    const separateCancel = cancelable && !allChoices.includes("Cancel");
    const labels = separateCancel ? [...allChoices, "Cancel"] : allChoices;
    const buttonWidth = labels.reduce((total, label) => {
      choiceMetrics.text = Lua.tr(Ltk.processPrompt(label)).replace(/<[^>]*>/g, "");
      return total + choiceMetrics.advanceWidth + 16;
    }, 0);
    if (labels.length && buttonWidth + 24 <= room.width) {
      dataModel.askForOptions(sender, [
        choices, allChoices, limits, separateCancel, skill, prompt || `#AskForChoice:::${skill}`, single,
      ]);
    } else {
      dataModel.askForChoices(sender, request);
    }
  }

  DiscardPileButton {
    anchors.top: parent.top
    anchors.topMargin: 32
    anchors.right: parent.right
    anchors.rightMargin: 120
    z: 10
    count: room.discardCount
    onClicked: discardPanel.open()
  }

  DiscardPilePanel {
    id: discardPanel
    parent: room
    readCards: () => JSON.parse(Lua.ev("json.encode(ClientInstance:discardCardsForDisplay())"))
    onInspect: cardId => room.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "CardDetail"), { cardId })
  }

  function refreshDiscard() {
    discardCount = Lua.ev("ClientInstance and ClientInstance.discard_pile and #ClientInstance.discard_pile or 0");
    discardPanel.refresh();
  }

  PindianDisplay {
    id: pindianDisplay
    x: room.tablePile.x
    y: room.tablePile.y
    width: room.tablePile.width
    z: 100
    cardPicture: name => SkinBank.getCardPicture(name)
  }

  function ciCardsForDisplay(playerId) {
    room.ciRevision;
    const cards = JSON.parse(Lua.ev(`json.encode(ClientInstance:ciCardsForDisplay(${playerId}))`));
    return cards === false ? null : Array.from(cards);
  }

  Component { id: ciMark; CiMarkButton {} }
  Component { id: ciPile; CiPile { onCanceled: room.closeInfoPopup() } }
  Component { id: markTooltips; PortraitMarkTooltips {} }
  Component { id: referencePane; SkillReferencePane {} }
  Component { id: stateButton; SkillStatusButton {} }
  Component { id: privateGeneralModel; Binding { property: "dataModel" } }
  Component {
    id: focusedSeat
    Text {
      id: seat
      objectName: "qiaoFocusedSeat"
      required property Item photo
      readonly property bool ownPhoto: photo.playerid === room.dataModel.dashboardId
      readonly property bool inFocus: photo.progressBar.visible || photo.progressTip !== ""
      readonly property Item normalSeat: photo.children.find(child => child instanceof GlowText
        && child.anchors.bottomMargin === -24) ?? null
      // The core exposes the text value as progressTip. Its visual item is
      // inside the scaled image attached directly below the progress bar.
      readonly property Item focusTip: photo.children.find(child => child instanceof Image
        && /\/control\/tip(?:\.[a-z]+)?$/i.test(child.source.toString())) ?? null
      readonly property Item focusText: focusTip?.children.find(child => child instanceof Text) ?? null
      readonly property var numerals: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二"]
      readonly property string numeral: numerals[photo.seatNumber - 1] ?? ""
      text: numeral === "" ? "" : numeral + "号位"
      x: {
        if (ownPhoto) return photo.photoMask.x + (photo.photoMask.width - width) / 2;
        if (focusText) return focusTip.x + (focusText.x + focusText.width / 2) * focusTip.scale - width / 2;
        return (photo.width - width) / 2;
      }
      y: {
        if (ownPhoto) return photo.photoMask.y - height - 4;
        if (focusText) return focusTip.y + (focusText.y + focusText.height) * focusTip.scale + 2;
        return photo.progressBar.y + photo.progressBar.height + 2;
      }
      z: 5
      visible: photo.playerid !== 0 && photo.playerid !== -1 && numeral !== "" && inFocus
      color: "#fff2ce"
      font.family: Config.libianName
      font.pixelSize: 15
      style: Text.Outline
      styleColor: "#352a21"

      Binding {
        target: seat.normalSeat
        property: "visible"
        when: seat.normalSeat !== null && seat.visible
        value: false
      }
    }
  }

  GeneralCardPresentation {
    id: roomGeneralAppearance
    enabledInContext: room.guestIllustrations
    factions: room.guestCardFactions
  }

  function bindOwnHiddenGenerals(item) {
    if (item.dataModel.playerid !== room.dataModel.dashboardId) return;
    const cardColumn = SkillLinks.findChild(item, child =>
      child.children.filter(card => card instanceof LtkComponents.GeneralCardItem).length === 2);
    if (!cardColumn) return;
    const context = privateGeneralContext.createObject(item, { player: item.dataModel });
    const cards = cardColumn.children.filter(card => card instanceof LtkComponents.GeneralCardItem);
    cards.forEach((card, index) => privateGeneralModel.createObject(item, {
      target: card,
      when: Qt.binding(() => !!context.generals[index]),
      value: Qt.binding(() => context.generals[index] ? Ltk.createGeneralCardModel(context.generals[index]) : null),
    }));
  }

  Component {
    id: privateGeneralContext

    QtObject {
      required property var player
      readonly property var generals: {
        room.ownHiddenGeneralsRevision;
        const id = player.playerid;
        if (Config.observing || Config.replaying || id !== Cpp.self.id
            || player.general !== "anjiang" || player.deputyGeneral !== "anjiang") return [];
        return JSON.parse(Lua.ev(`json.encode(ClientInstance:ownHiddenGenerals(${id}))`)) || [];
      }
    }
  }

  Connections {
    target: room.infoPopup

    function onItemChanged() {
      const item = room.infoPopup.item;
      roomGeneralAppearance.watch(item);
      if (item instanceof Info.PlayerDetail) {
        room.bindOwnHiddenGenerals(item);
        const tabs = SkillLinks.findChild(item, child => child instanceof Controls.SwipeView);
        const viewport = tabs?.itemAt(0);
        const text = SkillLinks.findChild(viewport, child => child instanceof LtkComponents.DescriptionText);
        SkillLinks.replaceText(referencePane, viewport, text, {
          active: Qt.binding(() => room.visible && room.infoPopup.visible && tabs.currentIndex === 0),
          rootText: (catalog, theme) => {
            const id = item.dataModel.playerid;
            if (id === 0 || id === undefined) return "";
            return SkillLinks.playerText(catalog, theme, Ltk.getPlayerSkills(id), name => Lua.tr(name),
              name => Lua.evaluate(`Fk:getDescription(${JSON.stringify(name)})`));
          },
        });
      } else if (item instanceof Info.GeneralDetail) {
        const text = SkillLinks.findChild(item, child => child instanceof LtkComponents.DescriptionText);
        if (!text) return;
        SkillLinks.replaceText(referencePane, item, text, {
          width: Qt.binding(() => Math.max(0, item.width - 40)),
          x: 20,
          active: Qt.binding(() => room.visible && room.infoPopup.visible),
          rootText: (catalog, theme) => {
            const groups = Array.from(item.generals, name => ({
              name, detail: Ltk.getGeneralDetail(name), factions: room.guestCardFactions[name],
            }));
            return SkillLinks.generalText(catalog, theme, groups, name => Lua.tr(name), true);
          },
        });
      }
    }
  }

  function refreshPileActions() {
    ++pileActionRevision;
  }

  function refreshPrelightButtons() {
    const model = dataModel.dashboard;
    const names = Array.from(model.fakeSkills, skill => skill.origName);
    for (const name of names) {
      if (name === "reveal_skill&" || !Lua.ev(`ClientInstance:canPrelightSkill(${JSON.stringify(name)})`)) {
        model.loseSkill(name, true);
        model.addSkill(name, false);
      }
    }
  }

  function refreshSkillButtonLabels() {
    const dashboard = dataModel.dashboard;
    const updateLabel = skill => {
      if (skill.name.length < 4) return true;
      const label = Lua.ev(`ClientInstance:skillButtonLabel(${JSON.stringify(skill.origName)}, ${JSON.stringify(skill.name)}, ${skill.isPrelight})`);
      if (label === false) return false;
      if (typeof label === "string" && label !== skill.name) skill.name = label;
      return true;
    };
    const visibleSkills = Array.from(dashboard.skills).filter(updateLabel);
    if (visibleSkills.length !== dashboard.skills.length)
      dashboard.skills = visibleSkills;
    for (const skill of dashboard.fakeSkills) updateLabel(skill);
  }

  Connections {
    target: room.dataModel.dashboard
    function onSkillsChanged() { Qt.callLater(room.refreshSkillButtonLabels); }
    function onFakeSkillsChanged() { Qt.callLater(room.refreshSkillButtonLabels); }
  }

  Column {
    id: openingCountdown
    objectName: "qiaoInitialPrelightCountdown"
    anchors.top: parent.top
    anchors.topMargin: 12
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(240, parent.width * 0.4)
    z: 10
    spacing: 2
    visible: openingAnimation.running

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Lua.tr("qiao_initial_prelight")
      color: "white"
      style: Text.Outline
      styleColor: "#262626"
    }

    Controls.ProgressBar {
      id: openingProgress
      width: parent.width
      from: 0
      to: 1
      NumberAnimation on value {
        id: openingAnimation
        running: false
        from: 1
        to: 0
      }
    }
  }

  function refreshMountDistances() {
    const labels = Lua.ev("json.encode(ClientInstance:mountDistanceLabels())");
    mountDistanceLabels = JSON.parse(labels ?? "{}");
  }

  // 横置、势力、移出游戏与技能有效性都可以在坐骑未移动时变化。
  Timer {
    interval: 200
    repeat: true
    running: room.visible && room.photoModel.count > 0
    onTriggered: room.refreshMountDistances()
  }

  Component {
    id: mountRow
    DualMountRow {}
  }

  function bindPhotoExtras() {
    guestIllustrations = !!GuestIllustration.enabledInRoom();
    for (let i = 0; i < photoModel.count; ++i) {
      const photo = photoModel.get(i).modelData.photoItem;
      if (!photo) continue;
      roomGeneralAppearance.watch(photo);
      if (!photo.children.some(child => child.objectName === "qiaoFocusedSeat"))
        focusedSeat.createObject(photo, { photo });
      const marks = photo?.picMarkArea;
      if (marks && !marks.children.some(child => child.objectName === "qiaoPortraitMarkTooltips"))
        markTooltips.createObject(marks);
      if (marks && !marks.children.some(child => child.objectName === "qiaoSkillStatus")) {
        stateButton.createObject(marks, {
          photo,
          states: Qt.binding(() => {
            room.skillStatusRevision;
            photo.general;
            photo.deputyGeneral;
            if (photo.dead || !photo.playerid) return [];
            return Array.from(JSON.parse(Lua.ev(`json.encode(ClientInstance:skillStates(${photo.playerid}))`) ?? "[]"));
          }),
        });
      }
      if (marks && !marks.children.some(child => child.objectName === "qiaoCiButton")) {
        const button = ciMark.createObject(marks, {
          cards: Qt.binding(() => room.ciCardsForDisplay(photo.playerid)),
        });
        button.clicked.connect(() => room.showInfoPopup(ciPile, {
          cardNames: Qt.binding(() => button.cards ?? []),
        }));
      }
      const area = photo?.areasSealed;
      if (!area || area.children.some(child => child.objectName === "qiaoDualMountRow"))
        continue;
      const defensive = area.items[area.subtypes.indexOf("defensive_ride")];
      const offensive = area.items[area.subtypes.indexOf("offensive_ride")];
      if (defensive && offensive) {
        mountRow.createObject(area, {
          defensiveItem: defensive,
          offensiveItem: offensive,
          distanceLabels: Qt.binding(() => room.mountDistanceLabels),
          isDualMount: name => Lua.evaluate(`Fk.packages.qiao_cards.qiao.isDualMount(${JSON.stringify(name)})`),
        });
      }
    }
    refreshMountDistances();
  }

  Connections {
    target: room.photoModel
    function onModelDataChanged() { Qt.callLater(room.bindPhotoExtras); }
  }

  Connections {
    target: room.dataModel
    function onCardsMoved() {
      ++room.skillStatusRevision;
      Qt.callLater(room.bindPhotoExtras);
      Qt.callLater(room.refreshDiscard);
    }
    function onSeatChanged() { Qt.callLater(room.bindPhotoExtras); }
  }

  function generalAppearance(name) {
    for (let i = 0; i < photoModel.count; ++i) {
      const photo = photoModel.get(i).modelData;
      if (name === photo.general)
        return { kingdom: photo.kingdom, skin: photo.skin?.name };
      if (name === photo.deputyGeneral)
        return { kingdom: photo.kingdom, skin: photo.deputySkin?.name };
    }
    return {};
  }

  function setVirtualPicture(card, name) {
    if (!card || !name) return;
    const picture = Lua.ev(`ClientInstance:virtualCardPicture(${JSON.stringify(name)})`);
    if (picture) card.picName = picture;
  }

  Component.onCompleted: {
    roomGeneralAppearance.watch(room);
    addCallback("QiaoGuestFactionsChanged", () => {
      guestIllustrations = !!GuestIllustration.enabledInRoom();
      ++room.guestFactionsRevision;
    });
    addCallback("QiaoSkillStatusChanged", () => { ++room.skillStatusRevision; });
    addCallback("QiaoPindianStart", () => {
      pindianDisplay.clear();
      App.showToast(Lua.tr("Pindian"));
    });
    addCallback("QiaoPindianResult", (_, data) => pindianDisplay.present(data));
    addCallback("QiaoDiscardChanged", () => Qt.callLater(room.refreshDiscard));
    addCallback("QiaoSingleChoice", room.showSingleChoice);
    addCallback("QiaoCiChanged", () => { ++room.ciRevision; });
    addCallback("QiaoOwnHiddenGeneralsChanged", () => { ++room.ownHiddenGeneralsRevision; });
    addCallback("QiaoRefreshPrelightButtons", room.refreshPrelightButtons);
    addCallback("QiaoPileActionChanged", () => Qt.callLater(room.refreshPileActions));
    addCallback("QiaoInitialPrelight", (_, data) => {
      const duration = Number(data[0]);
      if (duration > 0) {
        openingAnimation.duration = duration;
        openingAnimation.restart();
      }
    });
    addCallback(Command.ShowVirtualCard, (sender, data) => {
      const previous = new Set(tablePile.cards);
      showVirtualCard(sender, data);
      for (const card of tablePile.cards) {
        if (!previous.has(card))
          setVirtualPicture(card.dataModel, card.dataModel.name);
      }
    });
    addCallback(Command.SetCardVirtName, (sender, data) => {
      dataModel.setCardVirtName(sender, data);
      const [ids, name, virtual] = data;
      for (const card of tablePile.cards) {
        const model = card.dataModel;
        if (ids.includes(virtual ? model.virtId : model.cardId))
          setVirtualPicture(model, name);
      }
    });
    Qt.callLater(bindPhotoExtras);
    Qt.callLater(refreshSkillButtonLabels);
    Qt.callLater(refreshDiscard);
  }
}
