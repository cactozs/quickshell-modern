pragma ComponentBehavior: Bound

import QtQuick
import "../../../style"

// Small canvas sparkline for CPU/RAM history. Values are re-rendered only when
// the array or the geometry changes.
Canvas {
    id: root

    property var values: []
    property color lineColor: Theme.primary
    property real maxValue: 100

    implicitWidth: 74
    implicitHeight: 20

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const vals = root.values;
        if (!vals || vals.length < 2 || width <= 0 || height <= 0)
            return;

        const max = root.maxValue > 0 ? root.maxValue : 100;
        const stepX = width / (vals.length - 1);
        const yFor = v => height - 2 - Math.max(0, Math.min(1, Number(v) / max)) * (height - 4);

        ctx.beginPath();
        for (let i = 0; i < vals.length; i++) {
            const x = i * stepX;
            const y = yFor(vals[i]);
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }

        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Theme.alpha(root.lineColor, 0.26));
        grad.addColorStop(1, Theme.alpha(root.lineColor, 0.0));
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fillStyle = grad;
        ctx.fill();

        ctx.beginPath();
        for (let i = 0; i < vals.length; i++) {
            const x = i * stepX;
            const y = yFor(vals[i]);
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.strokeStyle = root.lineColor;
        ctx.lineWidth = 1.5;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();
    }
}
