pragma ComponentBehavior: Bound

import QtQuick
import "../../../style"

// Circular gauge drawn on a canvas: a muted track, an accent arc, and an
// optional Material icon or label in the middle. Used by the battery widget.
Item {
    id: root

    property real value: 0
    property int thickness: 7
    property color trackColor: Theme.surfaceContainerHigh
    property color fillColor: Theme.primary
    property string icon: ""
    property string label: ""
    property color labelColor: Theme.surfaceText
    property color iconColor: root.fillColor

    implicitWidth: 96
    implicitHeight: 96

    onValueChanged: ring.requestPaint()
    onThicknessChanged: ring.requestPaint()
    onTrackColorChanged: ring.requestPaint()
    onFillColorChanged: ring.requestPaint()
    onWidthChanged: ring.requestPaint()
    onHeightChanged: ring.requestPaint()

    Canvas {
        id: ring

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const c = Math.min(width, height) / 2;
            const r = c - root.thickness / 2 - 1;
            if (r <= 0)
                return;
            ctx.lineWidth = root.thickness;
            ctx.lineCap = "round";

            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.arc(c, c, r, 0, Math.PI * 2);
            ctx.stroke();

            const value = Math.max(0, Math.min(1, root.value));
            if (value > 0.001) {
                ctx.strokeStyle = root.fillColor;
                ctx.beginPath();
                ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * value);
                ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.icon !== ""
        text: root.icon
        color: root.iconColor
        font.family: Theme.iconFont
        font.pixelSize: 26
    }

    Text {
        anchors.centerIn: parent
        visible: root.label !== ""
        text: root.label
        color: root.labelColor
        font.family: Theme.fontFamily
        font.pixelSize: 24
        font.weight: Font.DemiBold
    }
}
