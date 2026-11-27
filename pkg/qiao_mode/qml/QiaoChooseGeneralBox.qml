// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import LunarLtk.Pages.Popups

ChooseGeneralBox {
  id: root

  SelectionAscensionBadges {
    cards: root.generalCardList
    eligible: root.dataModel.extraData.ascensions ?? ({})
    loyaltyEligible: root.dataModel.extraData.loyaltyAscensions ?? ({})
  }
}
