// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import Fk

Item {
  id: root
  objectName: "qiaoPortraitMarkTooltips"
  visible: false
  readonly property real windowWidth: Window.window?.width ?? Config.winWidth

  function styleMarks() {
    for (const mark of parent?.children ?? []) {
      // Native mark tips belong to the icon Image. The Ci tip belongs to the button.
      for (const anchor of [mark, ...mark.children]) {
        for (const tip of anchor.data) {
          if (!(tip instanceof Controls.ToolTip) || tip.objectName === "qiaoPortraitMarkTooltip") continue;
          tip.objectName = "qiaoPortraitMarkTooltip";
          tip.font = Qt.font({ family: "SimHei", styleHint: Font.SansSerif, pixelSize: 16 });
          tip.width = Qt.binding(() => Math.min(tip.implicitWidth, root.windowWidth * 0.4));
          tip.x = Qt.binding(() => ((tip.parent?.width ?? 0) - tip.width) / 2);
          tip.y = Qt.binding(() => -tip.height - 3);
        }
      }
    }
  }

  Connections {
    target: root.parent
    function onChildrenChanged() { Qt.callLater(root.styleMarks); }
  }

  Component.onCompleted: Qt.callLater(styleMarks)
}
