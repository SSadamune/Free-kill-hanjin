import QtQuick
import LunarLtk
import LunarLtk.Components

GeneralCardItem {
  id: card
  required property string generalName
  property var scene
  readonly property var appearance: Ltk.roomScene?.generalCardPresentation?.appearanceFor(dataModel?.known
    ? dataModel.name : "")

  dataModel: Ltk.createGeneralCardModel(generalName)

  GuestCardAppearance {
    card: card
    appearance: card.appearance
    inRoom: true
  }
}
