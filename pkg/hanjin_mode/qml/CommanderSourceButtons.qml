// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import Fk
import Fk.Components.Common
import LunarLtk

// 统领来源的同一用牌界面按钮组。`sources` / `currentKey` 由 Lua interaction
// 注入；key 是服务端权威 sourceKey，label 只用于显示，绝不回传翻译串。
Item {
  id: root

  property var sources: []
  property string currentKey: ""
  readonly property var scene: Ltk.roomScene

  readonly property Item progressItem: scene ? scene.progress : null

  // The loader owns this zero-size component. Its visual child shares the
  // progress bar's parent so Qt can maintain sibling anchors automatically.
  width: 0
  height: 0

  Flickable {
    id: viewport
    objectName: "hanjinCommanderSources"
    parent: root.progressItem ? root.progressItem.parent : root
    readonly property bool sharesProgressParent: root.progressItem !== null && parent === root.progressItem.parent
    anchors.horizontalCenter: sharesProgressParent ? root.progressItem.horizontalCenter : undefined
    anchors.bottom: sharesProgressParent ? root.progressItem.top : undefined
    anchors.bottomMargin: root.progressItem ? Math.max(0, promptMetrics.implicitHeight - root.progressItem.height) + 8 : 0
    visible: root.visible && root.scene !== null && root.scene.skillInteraction.visible && root.sources.length > 0
    z: 2

    width: root.scene ? Math.min(sourceRow.implicitWidth, root.scene.progress.width) : 0
    height: sourceRow.implicitHeight + (contentWidth > width ? 8 : 0)
    contentWidth: sourceRow.implicitWidth
    contentHeight: sourceRow.implicitHeight
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Text {
      id: promptMetrics
      visible: false
      text: root.scene ? root.scene.dataModel.promptText : ""
      textFormat: Text.RichText
      font.family: Config.libianName
      font.pixelSize: 16
    }

    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

    Row {
      id: sourceRow
      spacing: 6

      Repeater {
        model: root.sources

        delegate: MetroButton {
          required property var modelData

          text: modelData.label
          checked: root.currentKey === modelData.key
          onClicked: {
            if (root.currentKey === modelData.key) return;
            root.currentKey = modelData.key;
            Lua.updateRequestUI("Interaction", "1", "update", modelData.key);
          }
        }
      }
    }
  }

  Component.onCompleted: {
    if (!currentKey && sources.length > 0) currentKey = sources[0].key;
  }
}
