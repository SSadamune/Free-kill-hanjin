// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk
import Fk.Components.Common as Common
import LunarLtk
import LunarLtk.Components as Components
import LunarLtk.Components.Photo as PhotoParts
import "GuestIllustration.js" as GuestIllustration

QtObject {
  id: root
  required property bool enabledInContext
  required property var factions
  property bool onlyRegistered: false
  property bool inRoom: false

  function appearanceFor(name) {
    const known = name && name !== "anjiang";
    if (!known) return { guestFactions: [], factions: [] };
    const registered = factions?.[name] ?? [];
    const guestFactions = enabledInContext
      ? (inRoom ? GuestIllustration.roomFactions(registered) : registered) : [];
    const picture = GuestIllustration.picture(name,
      enabledInContext && (!onlyRegistered || guestFactions.length > 0));
    const printed = inRoom && !guestFactions.length ? Ltk.getGeneralData(name) : null;
    return { picture, guestFactions, factions: printed
      ? [printed.kingdom, printed.subkingdom].filter(Boolean) : guestFactions };
  }

  // Core and utility create their delegates dynamically. Attach once at the
  // room's visual roots, including the separate overlay used by info popups.
  function watch(item) {
    if (!(item instanceof Item) || item.objectName === "qiaoAppearanceWatcher") return;
    if (item instanceof Components.GeneralCardItem) {
      if (!item.children.some(child => child instanceof GuestCardAppearance))
        fullCard.createObject(item, { card: item });
    } else if (item instanceof Components.CompactGeneralCardItem) {
      if (item.children.some(child => child.objectName === "qiaoCompactGeneralArtwork")) return;
      const art = item.children.find(child => child instanceof Image && "useSmallPic" in child);
      if (art) compactCard.createObject(item, { card: item, art });
    } else if (item instanceof Components.PhotoBase) {
      const layer = item.children.find(child => child.maskSource === item.photoMask)?.source;
      if (!layer || item.children.some(child => child.objectName === "qiaoGuestPortrait")) return;
      const portraits = layer.children.filter(child => child instanceof Image);
      const skins = layer.children.filter(child => child instanceof PhotoParts.SkinMedia);
      if (portraits.length === 2)
        portraits.forEach((art, index) => portrait.createObject(item,
          { photo: item, art, skin: skins[index] ?? null, deputy: index === 1 }));
    } else if (item instanceof Components.CardItem) {
      if (!item.children.some(child => child.objectName === "qiaoGeneralCardArtwork"))
        generalAsCard.createObject(item, { card: item });
    } else if (inRoom && item instanceof Common.Avatar && item.parent?.parent?.modelData?._general !== undefined) {
      if (!item.children.some(child => child.objectName === "qiaoCompactGeneralArtwork"))
        compactCard.createObject(item, { art: item, skillAvatar: true });
    } else if (!(item instanceof Image || item instanceof Text)) {
      if (!item.children.some(child => child.objectName === "qiaoAppearanceWatcher"))
        containerWatcher.createObject(item);
      watchChildren(item);
    }
  }

  function watchChildren(item) {
    for (const child of item?.children ?? []) watch(child);
  }

  readonly property Component containerWatcher: Component {
    Item {
      id: watcher
      objectName: "qiaoAppearanceWatcher"
      function scan() { root.watchChildren(parent); }
      Connections {
        target: watcher.parent
        function onChildrenChanged() { Qt.callLater(watcher.scan); }
      }
    }
  }

  readonly property Component fullCard: Component {
    GuestCardAppearance {
      appearance: root.appearanceFor(card.dataModel?.known ? card.dataModel.name : "")
      inRoom: root.inRoom
      z: 1
    }
  }

  readonly property Component compactCard: Component {
    Item {
      id: compact
      objectName: "qiaoCompactGeneralArtwork"
      property Item card: null
      required property Image art
      property bool skillAvatar: false
      readonly property string name: skillAvatar ? art.general
        : (card?.dataModel?.known ? card.dataModel.name : "")
      readonly property var appearance: root.appearanceFor(name)
      readonly property Binding source: Binding {
        target: compact.art
        property: "source"
        when: !!compact.appearance.picture
        value: compact.appearance.picture
      }
      readonly property Binding crop: Binding {
        target: compact.art
        property: "sourceClipRect"
        when: !!compact.appearance.picture
        value: Qt.rect(0, 0, 0, 0)
      }
      readonly property Binding fill: Binding {
        target: compact.art
        property: "fillMode"
        when: !!compact.appearance.picture
        value: Image.PreserveAspectCrop
      }
      GuestFactionBadges {
        visible: root.inRoom
        standalone: true
        badgeSize: compact.skillAvatar ? 13 : 17
        factions: compact.appearance.factions
      }
    }
  }

  readonly property Component portrait: Component {
    Item {
      id: portraitArtwork
      objectName: "qiaoGuestPortrait"
      required property Item photo
      required property Image art
      property Item skin: null
      required property bool deputy
      readonly property string name: deputy ? photo.deputyGeneral : photo.general
      readonly property var appearance: root.appearanceFor(name)
      x: photo.photoMask.x + (deputy ? photo.photoMask.width / 2 : 0)
      y: photo.photoMask.y
      z: 1
      Binding {
        target: portraitArtwork.art
        property: "source"
        when: !!portraitArtwork.appearance.picture
        value: portraitArtwork.appearance.picture
      }
      Binding {
        target: portraitArtwork.skin
        property: "visible"
        when: root.inRoom && portraitArtwork.skin !== null
        value: false
      }
      GuestFactionBadges {
        visible: root.inRoom
        standalone: true
        badgeSize: portraitArtwork.photo.deputyGeneral ? 15 : 19
        factions: portraitArtwork.appearance.factions
      }
    }
  }

  readonly property Component generalAsCard: Component {
    Item {
      id: illustration
      objectName: "qiaoGeneralCardArtwork"
      required property Item card
      readonly property string graphic: card.dataModel?.picName ?? ""
      readonly property var appearance: root.appearanceFor(
        card.dataModel?.known && graphic.startsWith("general:") ? graphic.slice(8) : "")
      Binding {
        target: illustration.card
        property: "cardFrontSource"
        when: !!illustration.appearance.picture
        value: illustration.appearance.picture
      }
      GuestFactionBadges {
        // Poker-style cards use the left corner for suit and rank.
        x: illustration.card.width - 38 * (illustration.card.cardScale ?? 1)
        visible: root.inRoom
        standalone: true
        badgeSize: 14 * (illustration.card.cardScale ?? 1)
        factions: illustration.appearance.factions
      }
    }
  }
}
