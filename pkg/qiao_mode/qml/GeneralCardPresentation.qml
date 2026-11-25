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
  readonly property var attached: new WeakSet()

  // Core and utility create their delegates dynamically. Attach once at the
  // room's visual roots, including the separate overlay used by info popups.
  function watch(item) {
    if (!(item instanceof Item) || attached.has(item)) return;
    attached.add(item);
    if (item instanceof Ltk.GeneralCardItem) {
      if (!item.children.some(child => child instanceof GuestCardAppearance))
        fullCard.createObject(item, { card: item });
    } else if (item instanceof Ltk.CompactGeneralCardItem) {
      const art = item.children.find(child => child instanceof Image && "useSmallPic" in child);
      if (art) compactCard.createObject(item, { card: item, art });
    } else if (item instanceof Ltk.PhotoBase) {
      const layer = item.children.find(child => child.maskSource === item.photoMask)?.source;
      const portraits = layer?.children.filter(child => child instanceof Image) ?? [];
      if (portraits.length === 2)
        portraits.forEach((art, index) => portrait.createObject(layer, { photo: item, art, deputy: index === 1 }));
    } else if (item instanceof Ltk.CardItem) {
      generalAsCard.createObject(item, { card: item });
    } else if (!(item instanceof Image || item instanceof Text)) {
      item.childrenChanged.connect(() => Qt.callLater(watchChildren, item));
      watchChildren(item);
    }
  }

  function watchChildren(item) {
    for (const child of item?.children ?? []) watch(child);
  }

  readonly property Component fullCard: Component {
    GuestCardAppearance {
      enabledInContext: root.enabledInContext && (!root.onlyRegistered || factions.length > 0)
      factions: root.factions[card.dataModel?.name] ?? []
      z: 1
    }
  }

  readonly property Component compactCard: Component {
    QtObject {
      id: compact
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
    Image {
      required property Item photo
      required property Image art
      required property bool deputy
      readonly property string name: deputy ? photo.deputyGeneral : photo.general
      readonly property var skin: deputy ? photo.deputySkinSource : photo.skinSource
      anchors.fill: art
      fillMode: Image.PreserveAspectCrop
      source: !Config.banChangeSkin && skin?.name
        ? "" : (GuestIllustration.picture(name, root.enabledInContext) ?? "")
      visible: status === Image.Ready
    }
  }

  readonly property Component generalAsCard: Component {
    Binding {
      required property Item card
      readonly property string graphic: card.dataModel?.picName ?? ""
      readonly property var picture: card.dataModel?.known && graphic.startsWith("general:")
        ? GuestIllustration.picture(graphic.slice(8), root.enabledInContext) : undefined
      target: card
      property: "cardFrontSource"
      when: !!picture
      value: picture
    }
  }
}
