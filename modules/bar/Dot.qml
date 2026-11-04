import QtQuick
import "../../style"
import "../../services"

// One workspace dot for the bar. Geometry is passed in by Workspaces (it
// owns the row math); active/urgent are assigned in place by Workspaces'
// pool sync so the height spring plays across niri's model churn.
Rectangle {
    id: dot

    property int wsIdx
    property string output
    property int dimWidth
    property int dimHeight
    property int growHeight
    property bool active
    property bool urgent

    width: dimWidth
    height: active ? growHeight : dimHeight
    radius: dimWidth / 2
    anchors.verticalCenter: parent.verticalCenter
    color: urgent ? Theme.error : active ? Theme.primary : Theme.primaryContainer
    scale: ma.containsMouse ? 1.25 : 1

    Behavior on height {
        // one soft overshoot, not a wobble
        SpringAnimation { spring: 30; damping: 1.8; mass: 0.4 }
    }

    Behavior on color {
        ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
        NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Niri.focusWorkspace(dot.wsIdx, dot.output)
    }
}
