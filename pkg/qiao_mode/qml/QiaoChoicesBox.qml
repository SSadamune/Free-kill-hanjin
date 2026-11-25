// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models.Popups

GraphicsBox {
  id: root
  required property ChoicesModel dataModel

  readonly property bool useList: dataModel.allChoices.filter(choice => choice !== "Cancel").length > 6
  readonly property var choices: dataModel.allChoices.filter(choice => choice !== "Cancel")
  title.text: dataModel.promptText
  width: Math.min(740, Math.max(320, (parent?.width ?? 760) - 32))
  height: Math.min((parent?.height ?? 640) * 0.73, body.implicitHeight + title.height + 30)

  ColumnLayout {
    id: body
    anchors.fill: parent
    anchors.leftMargin: 18
    anchors.rightMargin: 18
    anchors.topMargin: root.title.height + 12
    anchors.bottomMargin: 12
    spacing: 8

    Controls.TextField {
      id: filter
      Layout.fillWidth: true
      visible: root.useList
      placeholderText: Lua.tr("Search")
    }

    ListView {
      id: options
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredHeight: Math.min(root.choices.length * 48, 330)
      clip: true
      spacing: 6
      model: root.choices.filter(choice => {
        if (!filter.text) return true;
        return Ltk.processPrompt(choice).toLocaleLowerCase().includes(filter.text.toLocaleLowerCase());
      })
      Controls.ScrollBar.vertical: Controls.ScrollBar {}

      delegate: RowLayout {
        id: row
        required property int index
        required property string modelData
        readonly property string label: Ltk.processPrompt(modelData)
        readonly property bool available: root.dataModel.choices.includes(modelData)
        readonly property bool abbreviated: label.replace(/<[^>]*>/g, "").length > 18
        width: options.width - 12
        opacity: available ? 1 : 0.5
        spacing: 8

        MetroButton {
          Layout.preferredWidth: 92
          visible: !root.useList
          text: row.abbreviated ? Lua.tr("qiao_choice_number").replace("%arg", row.index + 1) : row.label
          enabled: row.available
          checked: root.dataModel.result.includes(row.modelData)
          onClicked: root.dataModel.toggleChoose(row.modelData)
        }

        Controls.CheckBox {
          visible: root.useList
          enabled: row.available
          checked: root.dataModel.result.includes(row.modelData)
          nextCheckState: () => checked ? Qt.Unchecked : Qt.Checked
          onClicked: root.dataModel.toggleChoose(row.modelData)
        }

        Text {
          Layout.fillWidth: true
          text: {
            const labels = root.useList || row.abbreviated ? [row.label] : [];
            const key = ":" + row.modelData;
            const description = root.dataModel.detailed ? Lua.tr(key) : key;
            if (description !== key) labels.push(description);
            return labels.join("<br/>");
          }
          color: "#E4D5A0"
          font.pixelSize: 16
          textFormat: Text.RichText
          wrapMode: Text.Wrap
          TapHandler {
            enabled: root.useList && row.available
            onTapped: root.dataModel.toggleChoose(row.modelData)
          }
        }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      MetroButton {
        visible: !root.dataModel.single
        enabled: root.dataModel.feasible
        text: Lua.tr("OK")
        onClicked: root.dataModel.accepted()
      }
      MetroButton {
        visible: root.dataModel.cancelable || root.dataModel.choices.includes("Cancel")
        text: Lua.tr("Cancel")
        onClicked: root.dataModel.rejected()
      }
    }
  }
}
