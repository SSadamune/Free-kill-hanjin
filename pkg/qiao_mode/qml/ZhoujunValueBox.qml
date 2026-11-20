// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Pages.Popups

pragma ComponentBehavior: Bound

// 州郡领兵印准备阶段的三栏数值调整。`options` 由服务端按当前基数计算；
// 只有当前 (摸牌, 出杀, 手牌上限) 增减值命中其中一个合法组合时才能确认。
GraphicsBox {
  id: root

  property var options: []
  property var baseValues: ({ draw: 0, slash: 0, hand: 0 })
  property string prompt: ""
  property int drawValue: 0
  property int slashValue: 0
  property int handValue: 0

  readonly property bool legal: root.isLegal(root.drawValue, root.slashValue, root.handValue)

  function isLegal(draw, slash, hand) {
    for (let i = 0; i < root.options.length; i++) {
      const option = root.options[i];
      if (option.draw === draw && option.slash === slash && option.hand === hand)
        return true;
    }
    return false;
  }

  function canAdjust(key, delta) {
    const next = {
      draw: root.drawValue,
      slash: root.slashValue,
      hand: root.handValue
    };
    next[key] += delta;
    // 只允许仍可补足为合法分配的步骤，同时允许撤销已分配点数。
    return root.options.some(option => Object.keys(next).every(stat => {
      const value = next[stat];
      if (value > 0) return option[stat] >= value;
      if (value < 0) return root.baseValues[stat] + value >= 0 && option[stat] <= value;
      return true;
    }));
  }

  function adjust(key, delta) {
    if (!root.canAdjust(key, delta)) return;
    if (key === "draw") root.drawValue += delta;
    else if (key === "slash") root.slashValue += delta;
    else if (key === "hand") root.handValue += delta;
  }

  function deltaText(value) {
    if (value > 0) return "+" + value;
    if (value < 0) return "" + value;
    return "0";
  }

  function submit() {
    if (!root.legal) return;
    const reply = {
      draw: root.drawValue,
      slash: root.slashValue,
      hand: root.handValue
    };
    close();
    Ltk.roomModel.replyToServer(reply);
  }

  function cancel() {
    close();
    Ltk.roomModel.replyToServer("");
  }

  component ValueColumn: Column {
    id: column
    property string label
    property string stat
    property int value
    width: 150
    spacing: 8

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#E4D5A0"
      font.pixelSize: 18
      text: column.label
    }

    MetroButton {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 60
      height: 32
      text: "▲"
      enabled: root.canAdjust(column.stat, 1)
      onClicked: root.adjust(column.stat, 1)
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      color: column.value > 0 ? "#7BC47F" : (column.value < 0 ? "#D97A6C" : "#CFC3A8")
      font.bold: true
      font.pixelSize: 30
      text: root.baseValues[column.stat] + column.value
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#CFC3A8"
      font.pixelSize: 14
      text: "当前 " + root.baseValues[column.stat] + "（" + root.deltaText(column.value) + "）"
    }

    MetroButton {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 60
      height: 32
      text: "▼"
      enabled: root.canAdjust(column.stat, -1)
      onClicked: root.adjust(column.stat, -1)
    }
  }

  width: 620
  height: 340
  title.text: Ltk.processPrompt(root.prompt)

  Column {
    anchors.top: root.title.bottom
    anchors.topMargin: 16
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 12

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 24

      ValueColumn {
        label: "摸牌"
        stat: "draw"
        value: root.drawValue
      }

      ValueColumn {
        label: "出杀"
        stat: "slash"
        value: root.slashValue
      }

      ValueColumn {
        label: "手牌上限"
        stat: "hand"
        value: root.handValue
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      color: "#C9A26A"
      font.pixelSize: 15
      text: "将一项加 1 或 2，其余两项合计减等量"
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12

      MetroButton {
        width: 120
        height: 36
        text: Lua.tr("OK")
        enabled: root.legal
        onClicked: root.submit()
      }

      MetroButton {
        width: 120
        height: 36
        text: Lua.tr("Cancel")
        onClicked: root.cancel()
      }
    }
  }
}
