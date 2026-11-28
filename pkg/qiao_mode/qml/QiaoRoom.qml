// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk
import Fk.Components.Common
import Fk.Widgets as W
import LunarLtk
import LunarLtk.Components as LtkComponents
import LunarLtk.Components.Photo as PhotoElements
import LunarLtk.Pages
import LunarLtk.Pages.InfoPopups as Info
import "GuestIllustration.js" as GuestIllustration
import "SkillReferenceLinks.js" as SkillLinks
import "CardMoveVisibility.js" as CardMoveVisibility

Room {
  id: room
  property var mountDistanceLabels: ({})
  property bool guestIllustrations: false
  property var guestCardFactions: ({})
  readonly property alias generalCardPresentation: roomGeneralAppearance

  function refreshGeneralCardPresentation() {
    guestIllustrations = !!GuestIllustration.enabledInRoom();
    guestCardFactions = guestIllustrations
      ? JSON.parse(Lua.ev("json.encode(ClientInstance:guestCardFactions())") ?? "{}") : {};
  }
  property int pileActionRevision: 0
  property int ciRevision: 0
  property int ownHiddenGeneralsRevision: 0
  property int playerDetailSkillsRevision: 0
  property int skillStatusRevision: 0
  property int discardCount: 0
  property bool showSeats: false

  function refreshSeatVisibility() {
    showSeats = !!Lua.ev("ClientInstance:showSelectionSeats()");
  }

  readonly property string supportButtonLabel: {
    const fields = (dataModel.prompt ?? "").split(":");
    return fields[0] === "#qiao_adaptation_support" && fields[4]
      ? Lua.tr("qiao_condition_zhuzhan") + "→" + Lua.tr(fields[4]) : "";
  }
  Binding {
    target: room.okButton
    property: "text"
    when: room.supportButtonLabel !== ""
    value: room.supportButtonLabel
  }
  Binding {
    target: room.okButton
    property: "width"
    when: room.supportButtonLabel !== ""
    value: Math.max(136, room.supportButtonLabel.length * 21 + 20)
  }

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

  function edictCardsForDisplay(holderId) {
    room.skillStatusRevision;
    const cards = JSON.parse(Lua.ev(`json.encode(ClientInstance:edictCardsForDisplay(${holderId}))`));
    return cards === false ? [] : Array.from(cards);
  }

  function edictMarkCount(photo) {
    room.skillStatusRevision;
    return photo.dead || photo.playerid === 0 || photo.playerid === -1 ? false
      : Lua.ev(`ClientInstance:edictCountForDisplay(${photo.playerid})`);
  }

  function edictPanelState(holderId) {
    room.pileActionRevision;
    return JSON.parse(Lua.ev(`json.encode(ClientInstance:edictPanelState(${holderId}))`) ?? "{}");
  }

  function viewEdict(holderId) {
    if (edictPopup.visible && edictPopup.selecting) {
      if (edictPopup.holderId === holderId) return;
      Lua.updateRequestUI("QiaoEdict", edictPopup.holderId, "cancel", {});
    }
    if (edictPanelState(holderId).canOpen) {
      Lua.updateRequestUI("QiaoEdict", holderId, "open", {});
    } else {
      showEdictPanel(holderId, false);
    }
  }

  function showEdictPanel(holderId, selecting) {
    edictPopup.holderId = holderId;
    edictPopup.selecting = selecting;
    edictPopup.setSourceComponent(edictPile, {
      holderId,
      ids: Qt.binding(() => room.edictCardsForDisplay(holderId)),
      actions: Qt.binding(() => selecting ? room.edictPanelState(holderId) : ({})),
    });
    edictPopup.open();
  }

  W.PopupItem {
    id: edictPopup
    property int holderId
    property bool selecting: false
    width: Math.min(room.width - 16, Math.max(420 * Config.winScale, Config.winWidth * 0.6))
    height: Math.max(0, Math.min(Config.winHeight * 0.8, room.dashboard.y - 20))
    x: (room.width - width) / 2
    y: (room.dashboard.y - height) / 2
    focus: true
    closePolicy: selecting ? Controls.Popup.CloseOnEscape
      : Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    background: Rectangle {
      color: "#CC2E2C27"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
    onAboutToShow: room.closeInfoPopup()
    onAboutToHide: {
      if (selecting) Lua.updateRequestUI("QiaoEdict", holderId, "cancel", {});
    }
  }

  Connections {
    target: room.infoPopup
    function onAboutToShow() { edictPopup.close(); }
  }
  Binding {
    target: room.okButton.parent
    property: "visible"
    when: edictPopup.visible && edictPopup.selecting
    value: false
  }

  Component { id: ciMark; CiMarkButton {} }
  Component { id: ciPile; CiPile { onCanceled: room.closeInfoPopup() } }
  Component { id: markTooltips; PortraitMarkTooltips {} }
  Component { id: referencePane; SkillReferencePane { generalCardPresentation: roomGeneralAppearance } }
  Component { id: edictMark; EdictMarkButton {} }
  Component {
    id: edictPile
    EdictPile {
      onRequested: action => Lua.updateRequestUI("QiaoEdict", holderId, action, {})
    }
  }
  Component {
    id: statusLabels
    PortraitStatusLabels {
      id: panel
      required property Item photo
      readonly property var managedStates: {
        room.skillStatusRevision;
        room.playerDetailSkillsRevision;
        photo.general;
        photo.deputyGeneral;
        photo.dataModel.hp;
        photo.dataModel.maxHp;
        if (photo.dead || photo.playerid === 0 || photo.playerid === -1) return [];
        return Array.from(JSON.parse(Lua.ev(`json.encode(ClientInstance:skillStates(${photo.playerid}))`) ?? "[]"));
      }
      readonly property Item targetTip: photo.children.find(child => child instanceof PhotoElements.TargetTip) ?? null

      x: photo.markArea.x
      width: photo.markArea.width
      anchors.bottom: photo.areasSealed.top
      visible: photo.markArea.visible && states.length > 0
      interactive: photo.markArea.enabled
      states: {
        room.skillStatusRevision;
        if (photo.dead) return [];
        const managed = new Set(managedStates.map(entry => entry.id));
        const plain = value => String(value ?? "").replace(/<[^>]*>/g, "").trim();
        const entries = managedStates.slice();
        for (const mark of photo.dataModel.marks) {
          // Hegemony also sends the viewer a legacy text mark for their own seat.
          if (!mark || mark.origName === "@seat" || managed.has(mark.origName)) continue;
          const descriptionKey = ":" + mark.origName;
          const description = Lua.tr(descriptionKey);
          const count = mark.origName.startsWith("@@") ? photo.dataModel.luaPlayer.getMark(mark.origName) : 1;
          const entry = {
            id: mark.origName, title: plain(mark.name), value: plain(mark.value),
            description: mark.desc || (description === descriptionKey ? "" : description),
            qml: mark.qml,
          };
          const repeats = Number.isFinite(count) ? Math.max(1, Math.floor(count)) : 1;
          for (let i = 0; i < repeats; ++i) entries.push(entry);
        }
        return entries;
      }

      Binding {
        target: panel.photo.markArea
        property: "markModel"
        value: []
      }
      Binding {
        target: panel.targetTip
        property: "z"
        when: panel.targetTip !== null && panel.visible
        value: 1
      }

      onActivated: entry => {
        const holderId = photo.playerid;
        const cards = Qt.binding(() => photo.playerid === holderId
          ? panel.managedStates.find(state => state.id === entry.id)?.cards ?? [] : []);
        if (entry.action === "edict") {
          room.viewEdict(holderId);
        } else if (entry.action === "pojun") {
          room.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "ViewPile"), {
            name: "qiao__skill_wu020_2", ids: cards,
            additional_prop: { selectable: true, known: true },
          });
        } else if (entry.qml) {
          const spec = entry.qml;
          const props = Object.assign({}, spec.prop);
          if (spec.model) props.dataModel = Lua.createQmlObject(spec.model);
          room.showInfoPopup(Lua.createComponent(spec), props);
        }
      }
    }
  }
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
      visible: room.showSeats && photo.playerid !== 0 && photo.playerid !== -1 && numeral !== "" && inFocus
      color: "#fff2ce"
      font.family: Config.libianName
      font.pixelSize: 15
      style: Text.Outline
      styleColor: "#352a21"

      Binding {
        target: seat.normalSeat
        property: "visible"
        when: seat.normalSeat !== null && (!room.showSeats || seat.visible)
        value: false
      }
    }
  }

  GeneralCardPresentation {
    id: roomGeneralAppearance
    inRoom: true
    enabledInContext: room.guestIllustrations
    factions: room.guestCardFactions
  }

  onPopupItemChanged: roomGeneralAppearance.watch(popupItem)

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
            || (player.general !== "anjiang" && player.deputyGeneral !== "anjiang")) return [];
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
            room.playerDetailSkillsRevision;
            const id = item.dataModel.playerid;
            if (id === 0 || id === -1 || id === undefined) return "";
            const skills = JSON.parse(Lua.ev(`json.encode(ClientInstance:playerDetailSkills(${id}))`) ?? "[]");
            return SkillLinks.playerText(catalog, theme, Array.from(skills), name => Lua.tr(name),
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
              name, detail: Ltk.getGeneralDetail(name), factions: roomGeneralAppearance.appearanceFor(name).factions,
            }));
            return SkillLinks.generalText(catalog, theme, groups, name => Lua.tr(name), true);
          },
        });
      }
    }
  }

  function refreshPileActions() {
    ++pileActionRevision;
    if (edictPopup.visible && edictPopup.selecting && !edictPanelState(edictPopup.holderId).selecting)
      edictPopup.close();
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
  Component {
    id: equipSlotLabel
    EquipSlotLabel {}
  }

  // 原生 SetCardMark 更新手牌和处理区。装备槽有自己的 CardModel。
  function setCardMark(sender, data) {
    dataModel.setCardMark(sender, data);
    const [id, mark, value] = data;
    if (mark !== "@qiao_bajia_yu") return;
    for (let i = 0; i < photoModel.count; ++i) {
      const slots = photoModel.get(i).modelData.photoItem?.areasSealed?.items ?? [];
      for (const slot of slots) {
        const card = slot.equips.find(equip => equip.cardId === id);
        if (card) {
          Ltk.setMark(card.marks, mark, value);
          return;
        }
      }
    }
  }

  function bindPhotoExtras() {
    for (let i = 0; i < photoModel.count; ++i) {
      const photo = photoModel.get(i).modelData.photoItem;
      if (!photo) continue;
      roomGeneralAppearance.watch(photo);
      if (!photo.children.some(child => child.objectName === "qiaoFocusedSeat"))
        focusedSeat.createObject(photo, { photo });
      const marks = photo?.picMarkArea;
      if (marks && !marks.children.some(child => child.objectName === "qiaoPortraitMarkTooltips"))
        markTooltips.createObject(marks);
      if (photo.markArea && !photo.children.some(child => child.objectName === "qiaoPortraitStatusLabels"))
        statusLabels.createObject(photo, { photo });
      if (marks && !marks.children.some(child => child.objectName === "qiaoEdictMark")) {
        const button = edictMark.createObject(marks, {
          count: Qt.binding(() => room.edictMarkCount(photo)),
        });
        button.clicked.connect(() => room.viewEdict(photo.playerid));
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
      for (const slot of area.items) {
        if (slot !== defensive && slot !== offensive &&
            !slot.children.some(child => child.objectName === "qiaoEquipSlotLabel")) {
          equipSlotLabel.createObject(slot, { slot });
        }
      }
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
    function onDeActivated() { Qt.callLater(room.refreshPileActions); }
    function onCardsMoved() {
      ++room.skillStatusRevision;
      Qt.callLater(room.bindPhotoExtras);
      Qt.callLater(room.refreshDiscard);
    }
    function onSeatChanged() {
      ++room.skillStatusRevision;
      Qt.callLater(room.bindPhotoExtras);
    }
  }

  function setVirtualPicture(card, name) {
    if (!card || !name) return;
    const picture = Lua.ev(`ClientInstance:virtualCardPicture(${JSON.stringify(name)})`);
    if (picture) card.picName = picture;
  }

  Component.onCompleted: {
    refreshSeatVisibility();
    refreshGeneralCardPresentation();
    roomGeneralAppearance.watch(room);
    addCallback("QiaoMoveCards", (_, data) => CardMoveVisibility.moveCards(dataModel, data, Ltk.Card, Cpp.self.id, tablePile));
    addCallback("QiaoGuestFactionsChanged", refreshGeneralCardPresentation);
    addCallback("QiaoSelectionFinished", refreshSeatVisibility);
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
    addCallback("QiaoPlayerDetailSkillsChanged", () => { ++room.playerDetailSkillsRevision; });
    addCallback("QiaoRefreshPrelightButtons", room.refreshPrelightButtons);
    addCallback("QiaoPileActionChanged", () => Qt.callLater(room.refreshPileActions));
    addCallback("QiaoOpenEdict", (_, data) => room.showEdictPanel(data[0], true));
    addCallback("QiaoInitialPrelight", (_, data) => {
      const duration = Number(data[0]);
      if (duration > 0) {
        openingAnimation.duration = duration;
        openingAnimation.restart();
      }
    });
    addCallback(Command.SetCardMark, room.setCardMark);
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
