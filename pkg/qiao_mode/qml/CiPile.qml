// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Components.Common
import LunarLtk.Components

ColumnLayout {
  id: root
  anchors.fill: parent

  objectName: "qiaoCiPile"
  property string name
  property list<string> cardNames
  property string selectedCi: ""
  property var chooseCard

  BigGlowText {
    Layout.fillWidth: true
    Layout.preferredHeight: childrenRect.height + 4
    text: Lua.tr(root.name)
  }

  GridView {
    Layout.preferredWidth: root.width - root.width % 97
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignHCenter
    cellWidth: 97
    cellHeight: 134
    clip: true
    model: root.cardNames

    delegate: QiaoGeneralCard {
      required property string modelData
      autoBack: false
      generalName: modelData
      selectable: !!root.chooseCard
      chosenInBox: root.selectedCi === modelData
      onClicked: {
        if (root.chooseCard) root.selectedCi = root.selectedCi === modelData ? "" : modelData;
      }
    }
  }

  MetroButton {
    Layout.alignment: Qt.AlignHCenter
    text: Lua.tr("OK")
    visible: !!root.chooseCard
    enabled: root.cardNames.includes(root.selectedCi)
    onClicked: root.chooseCard(root.selectedCi)
  }
}
