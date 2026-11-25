// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk
import LunarLtk.Pages
import "GuestIllustration.js" as GuestIllustration

Room {
  id: room
  property var mountDistanceLabels: ({})
  property bool guestIllustrations: false
  property int pileActionRevision: 0
  property int ciRevision: 0

  Row {
    id: recordsButtons
    anchors.top: parent.top
    anchors.topMargin: 36
    anchors.right: parent.right
    anchors.rightMargin: 120
    z: 10
    spacing: 4
    Controls.Button {
      text: "弃牌堆"
      onClicked: discardPanel.open()
    }
    Controls.Button {
      text: "拼点记录"
      onClicked: pindianPanel.openHistory()
    }
  }

  DiscardPilePanel {
    id: discardPanel
    parent: room
    readCards: () => JSON.parse(Lua.ev("json.encode(ClientInstance:discardCardsForDisplay())"))
  }

  PindianPanel {
    id: pindianPanel
    anchors.fill: parent
    z: 11
    readHistory: () => JSON.parse(Lua.ev("json.encode(ClientInstance:pindianHistory())"))
    translate: key => Lua.tr(key)
  }

  function ciCardsForDisplay(playerId) {
    room.ciRevision;
    const cards = JSON.parse(Lua.ev(`json.encode(ClientInstance:ciCardsForDisplay(${playerId}))`));
    return cards === false ? null : Array.from(cards);
  }

  Component { id: ciMark; CiMarkButton {} }
  Component { id: ciPile; CiPile {} }

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

  Component {
    id: guestPortrait
    Image {
      required property Item portrait
      required property Item photo
      required property bool deputy
      anchors.fill: portrait
      fillMode: Image.PreserveAspectCrop
      source: {
        const name = deputy ? photo.deputyGeneral : photo.general;
        if (!name || name === "anjiang") return "";
        const skin = deputy ? photo.deputySkinSource : photo.skinSource;
        if (!Config.banChangeSkin && skin?.name) return "";
        return GuestIllustration.picture(name, room.guestIllustrations) ?? "";
      }
      visible: status === Image.Ready
    }
  }

  function bindGuestPortraits(photo) {
    if (!photo) return;
    // Reuse PhotoBase's masked art layer so names, dimming and other UI stay above it.
    const art = photo.children.find(child => child.maskSource === photo.photoMask)?.source;
    if (!art || art.children.some(child => child.objectName === "qiaoGuestPortrait")) return;
    const portraits = art.children.filter(child => child instanceof Image);
    if (portraits.length !== 2) return;
    portraits.forEach((portrait, index) => guestPortrait.createObject(art, {
      objectName: "qiaoGuestPortrait", portrait, photo, deputy: index === 1,
    }));
  }

  function bindPhotoExtras() {
    guestIllustrations = !!GuestIllustration.enabledInRoom();
    for (let i = 0; i < photoModel.count; ++i) {
      const photo = photoModel.get(i).modelData.photoItem;
      bindGuestPortraits(photo);
      const marks = photo?.picMarkArea;
      if (marks && !marks.children.some(child => child.objectName === "qiaoCiButton")) {
        const button = ciMark.createObject(marks, {
          cards: Qt.binding(() => room.ciCardsForDisplay(photo.playerid)),
        });
        button.clicked.connect(() => room.showInfoPopup(ciPile, {
          holderId: photo.playerid, name: "@[qiao_ci]",
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
      Qt.callLater(room.bindPhotoExtras);
      if (discardPanel.visible) Qt.callLater(discardPanel.refresh);
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
    addCallback("QiaoPindianResult", (_, data) => pindianPanel.present(data));
    addCallback("QiaoDiscardChanged", () => { if (discardPanel.visible) Qt.callLater(discardPanel.refresh); });
    addCallback("QiaoCiChanged", () => { ++room.ciRevision; });
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
  }
}
