// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk
import LunarLtk.Components as Ltk
import "GuestIllustration.js" as GuestIllustration

QtObject {
  id: root
  required property bool enabledInContext
  required property var factions
  property bool onlyRegistered: false
  // Core and utility create their delegates dynamically. Attach once at the
  // room's visual roots, including the separate overlay used by info popups.
  function watch(item) {
    if (!(item instanceof Item) || item.objectName === "qiaoAppearanceWatcher") return;
    if (item instanceof Ltk.GeneralCardItem) {
      if (!item.children.some(child => child instanceof GuestCardAppearance))
        fullCard.createObject(item, { card: item });
    } else if (item instanceof Ltk.CompactGeneralCardItem) {
      if (item.children.some(child => child.objectName === "qiaoCompactGeneralArtwork")) return;
      const art = item.children.find(child => child instanceof Image && "useSmallPic" in child);
      if (art) compactCard.createObject(item, { card: item, art });
    } else if (item instanceof Ltk.PhotoBase) {
      const layer = item.children.find(child => child.maskSource === item.photoMask)?.source;
      if (!layer || layer.children.some(child => child.objectName === "qiaoGuestPortrait")) return;
      const portraits = layer.children.filter(child => child instanceof Image);
      if (portraits.length === 2)
        portraits.forEach((art, index) => portrait.createObject(layer, { photo: item, art, deputy: index === 1 }));
    } else if (item instanceof Ltk.CardItem) {
      if (!item.children.some(child => child.objectName === "qiaoGeneralCardArtwork"))
        generalAsCard.createObject(item, { card: item });
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
      enabledInContext: root.enabledInContext && (!root.onlyRegistered || factions.length > 0)
      factions: root.factions[card.dataModel?.name] ?? []
      z: 1
    }
  }

  readonly property Component compactCard: Component {
    Item {
      id: compact
      objectName: "qiaoCompactGeneralArtwork"
      required property Item card
      required property Image art
      readonly property var picture: card.dataModel?.known
        ? GuestIllustration.picture(card.dataModel.name, root.enabledInContext) : undefined
      readonly property Binding source: Binding {
        target: compact.art
        property: "source"
        when: !!compact.picture
        value: compact.picture
      }
      readonly property Binding crop: Binding {
        target: compact.art
        property: "sourceClipRect"
        when: !!compact.picture
        value: Qt.rect(0, 0, 0, 0)
      }
      readonly property Binding fill: Binding {
        target: compact.art
        property: "fillMode"
        when: !!compact.picture
        value: Image.PreserveAspectCrop
      }
    }
  }

  readonly property Component portrait: Component {
    Item {
      id: portraitArtwork
      objectName: "qiaoGuestPortrait"
      required property Item photo
      required property Image art
      required property bool deputy
      readonly property string name: deputy ? photo.deputyGeneral : photo.general
      readonly property var picture: GuestIllustration.picture(name, root.enabledInContext)
      // The original image is already part of the masked texture and sits
      // behind its skin layer. Change only that image's source.
      Binding {
        target: portraitArtwork.art
        property: "source"
        when: !!portraitArtwork.picture
        value: portraitArtwork.picture
      }
    }
  }

  readonly property Component generalAsCard: Component {
    Item {
      id: illustration
      objectName: "qiaoGeneralCardArtwork"
      required property Item card
      readonly property string graphic: card.dataModel?.picName ?? ""
      readonly property var picture: card.dataModel?.known && graphic.startsWith("general:")
        ? GuestIllustration.picture(graphic.slice(8), root.enabledInContext) : undefined
      Binding {
        target: illustration.card
        property: "cardFrontSource"
        when: !!illustration.picture
        value: illustration.picture
      }
    }
  }
}
