// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Item {
  id: panel
  required property var readHistory
  required property var translate
  property var current: null
  property var pending: []
  property var records: []

  function refreshHistory() {
    records = Array.from(readHistory() || []).reverse();
  }
  function openHistory() {
    advanceTimer.stop();
    current = null;
    pending = [];
    refreshHistory();
    history.open();
    historyList.positionViewAtBeginning();
  }
  function advance() {
    current = pending[0] || null;
    pending = pending.slice(1);
    if (current) advanceTimer.restart();
  }
  function present(record) {
    if (history.visible) {
      refreshHistory();
      return;
    }
    pending = pending.concat([record]);
    if (!current) advance();
  }
  Timer { id: advanceTimer; interval: 6000; onTriggered: panel.advance() }

  Loader {
    anchors.top: parent.top; anchors.topMargin: 76
    anchors.right: parent.right; anchors.rightMargin: 12
    width: Math.min(328, panel.width - 24)
    active: !!panel.current
    sourceComponent: Component {
      PindianSummary {
        // Loader 可在绑定重算后才销毁旧实例。
        record: panel.current || ({ targets: [], source: null, reason: "", sequence: "" })
        translate: panel.translate
        compact: true
        TapHandler { onTapped: panel.openHistory() }
      }
    }
  }

  Controls.Popup {
    id: history
    objectName: "qiaoPindianHistory"
    parent: panel
    width: Math.min(510, panel.width - 16)
    height: Math.min(375, panel.height - 16)
    x: Math.round((panel.width - width) / 2)
    y: Math.round((panel.height - height) / 2)
    focus: true; padding: 12
    contentItem: ColumnLayout {
      RowLayout {
        Layout.fillWidth: true
        Controls.Label { text: "拼点记录"; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true }
        Controls.Button { text: "关闭"; onClicked: history.close() }
      }
      ListView {
        id: historyList
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 5; clip: true
        model: panel.records
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        delegate: PindianSummary {
          required property var modelData
          width: historyList.width - 8; record: modelData; translate: panel.translate
        }
        Controls.Label { visible: !historyList.count; anchors.centerIn: parent; text: "本局还没有拼点结果" }
      }
    }
  }
}
