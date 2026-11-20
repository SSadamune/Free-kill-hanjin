// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Canvas {
  id: border

  required property var colors
  readonly property int strokeWidth: 2
  readonly property var segments: {
    const w = width - strokeWidth;
    const h = height - strokeWidth;
    if (!colors.length || w <= 0 || h <= 0) return [];

    const inset = strokeWidth / 2;
    const middle = width / 2;
    const right = width - inset;
    const bottom = height - inset;
    const perimeter = 2 * (w + h);
    // Walk counterclockwise from the top center, along the center of the stroke.
    const corners = [
      { distance: 0, x: middle, y: inset },
      { distance: w / 2, x: inset, y: inset },
      { distance: w / 2 + h, x: inset, y: bottom },
      { distance: 1.5 * w + h, x: right, y: bottom },
      { distance: 1.5 * w + 2 * h, x: right, y: inset },
      { distance: perimeter, x: middle, y: inset },
    ];

    function pointAt(distance) {
      if (distance >= perimeter) return corners[corners.length - 1];
      const end = corners.findIndex(point => point.distance >= distance);
      if (end === 0) return corners[0];
      const a = corners[end - 1];
      const b = corners[end];
      const progress = (distance - a.distance) / (b.distance - a.distance);
      return { x: a.x + (b.x - a.x) * progress, y: a.y + (b.y - a.y) * progress };
    }

    return colors.map((color, index) => {
      const start = index * perimeter / colors.length;
      const end = (index + 1) * perimeter / colors.length;
      const points = corners.filter(point => point.distance > start && point.distance < end);
      return { color, points: [pointAt(start)].concat(points, pointAt(end)) };
    });
  }

  visible: colors.length > 0
  antialiasing: false
  onAvailableChanged: if (available) requestPaint()
  onSegmentsChanged: if (available) requestPaint()

  onPaint: {
    const ctx = getContext("2d");
    ctx.clearRect(0, 0, width, height);
    ctx.lineWidth = strokeWidth;
    ctx.lineCap = "butt";
    ctx.lineJoin = "miter";
    for (const segment of segments) {
      const points = segment.points;
      ctx.beginPath();
      ctx.moveTo(points[0].x, points[0].y);
      for (let i = 1; i < points.length; ++i) ctx.lineTo(points[i].x, points[i].y);
      ctx.strokeStyle = segment.color;
      ctx.stroke();
    }
  }
}
