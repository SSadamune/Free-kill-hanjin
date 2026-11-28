// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Column {
  id: panel
  objectName: "qiaoPortraitStatusLabels"
  required property var states
  property bool interactive: true
  signal activated(var entry)

  readonly property var rows: {
    const ordered = states.filter(state => state.parameterized ?? !!state.value)
      .concat(states.filter(state => !(state.parameterized ?? !!state.value)));
    const rowCount = Math.min(3, ordered.length);
    if (!rowCount) return [];

    const evenShare = Math.floor(ordered.length / rowCount);
    const smallerRows = rowCount - ordered.length % rowCount;
    const result = [];
    let first = 0;
    for (let i = 0; i < rowCount; ++i) {
      // Put extra slots in the lower rows so shorter labels are grouped first.
      const last = first + evenShare + (i >= smallerRows ? 1 : 0);
      result.push(ordered.slice(first, last));
      first = last;
    }
    return result;
  }

  spacing: 2

  Repeater {
    model: panel.rows.length
    delegate: Item {
      id: row
      objectName: "qiaoPortraitStatusRow"
      required property int index
      readonly property var entries: panel.rows[index] ?? []
      readonly property real slotWidth: width / Math.max(1, entries.length)
      readonly property int hoveredIndex: pointer.hovered
        ? Math.min(entries.length - 1, Math.max(0, Math.floor(pointer.point.position.x / slotWidth))) : -1
      width: panel.width
      height: 18

      HoverHandler { id: pointer }

      Repeater {
        model: row.entries.length
        delegate: PortraitStatusLabel {
          required property int index
          entry: row.entries[index]
          x: index * row.slotWidth
          width: row.slotWidth
          height: row.height
          inset: row.entries.length === 1 ? 0 : Math.min(0.5, width / 4)
          hovered: row.hoveredIndex === index
          expanded: hovered && row.entries.length > 1
          covered: row.hoveredIndex !== -1 && !hovered
          interactive: panel.interactive
          onActivated: panel.activated(entry)
        }
      }
    }
  }
}
