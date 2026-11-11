// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk

// 统领来源的同一用牌界面按钮组。`sources` / `currentKey` 由 Lua interaction
// 注入；key 是服务端权威 sourceKey，label 只用于显示，绝不回传翻译串。
Flow {
  id: root

  property var sources: []
  property string currentKey: ""

  spacing: 4
  width: 360

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

  Component.onCompleted: {
    if (!currentKey && sources.length > 0) currentKey = sources[0].key;
  }
}
