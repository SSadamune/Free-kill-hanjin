// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components

ColumnLayout {
  id: root
  anchors.fill: parent

  required property int holderId
  property string name
  property list<string> cardNames
  property string selectedCi: ""
  readonly property var scene: Ltk.roomScene
  readonly property bool isHolder: !Config.observing && !Config.replaying && Cpp.self.id === holderId

  function canConsume() {
    return root.cardNames.includes(root.selectedCi) &&
      Lua.ev(`ClientInstance:canConsumeCi(${holderId}, ${JSON.stringify(root.selectedCi)})`);
  }

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
      scene: root.scene
      chosenInBox: root.selectedCi === modelData
      onClicked: {
        if (root.isHolder) root.selectedCi = root.selectedCi === modelData ? "" : modelData;
      }
    }
  }

  MetroButton {
    Layout.alignment: Qt.AlignHCenter
    text: Lua.tr("qiao__ci_consume")
    visible: root.isHolder
    enabled: {
      // The Lua query itself has no QML change signal.
      root.scene?.pileActionRevision;
      return visible && root.scene?.progress.visible && root.canConsume();
    }

    onClicked: {
      if (!root.canConsume()) return;
      root.scene.closeInfoPopup();
      Lua.updateRequestUI("QiaoCi", root.holderId, "click", { general: root.selectedCi });
    }
  }
}
