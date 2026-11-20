import QtQuick
import Fk
import LunarLtk
import LunarLtk.Components
import LunarLtk.Components.Photo
import "GuestIllustration.js" as GuestIllustration

GeneralCardItem {
  id: card
  required property string generalName
  property var scene
  property string preferredSkin: ""
  readonly property var appearance: scene?.generalAppearance?.(generalName) ?? ({})
  readonly property string activeSkin: Config.banChangeSkin ? "" : (appearance.skin ?? preferredSkin)

  dataModel: {
    const properties = appearance.kingdom ? { kingdom: appearance.kingdom, subkingdom: "" } : {};
    return Ltk.createGeneralCardModel(generalName, properties);
  }
  cardFrontSource: GuestIllustration.picture(generalName, scene?.guestIllustrations) ?? dataModel.frontSkin

  SkinArea {
    parent: card.cardBg
    anchors.fill: parent
    z: 1
    general: card.generalName
    skinName: card.activeSkin
    enabledShown: true
    visible: card.activeSkin !== ""
  }
}
