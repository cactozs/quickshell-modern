pragma ComponentBehavior: Bound

import QtQuick
import "../../services"
import "../../style"

// Clickable workspace chips for one niri output. The active chip widens and
// takes the matugen primary; an urgent chip gets an error-tinted outline.
Row {
    id: root

    // niri output whose workspaces to show (the bar's screen).
    property string screenName
    property int pillHeight: 28

    spacing: 6

    Repeater {
        model: Niri.workspacesFor(root.screenName)

        delegate: Rectangle {
            id: pill

            required property var modelData

            readonly property bool active: modelData.is_active ?? false
            readonly property bool urgent: modelData.is_urgent ?? false

            // The active chip shows the workspace name when niri has one
            // beyond the bare index, everything else shows the index.
            readonly property string label: {
                const ws = pill.modelData;
                if (pill.active) {
                    const name = (ws.name ?? "").trim();
                    if (name !== "" && name !== String(ws.idx))
                        return name;
                }
                return String(ws.idx);
            }

            width: label.implicitWidth + 20
            height: root.pillHeight
            radius: height / 2
            color: pill.active ? Theme.primary : "transparent"
            border.width: pill.active ? 0 : 1
            border.color: pill.urgent ? Theme.error : Theme.plateBorder
            opacity: pill.active || pill.urgent ? 1 : 0.75

            Behavior on width {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                id: label

                anchors.centerIn: parent
                text: pill.label
                color: pill.active ? Theme.onPrimary : Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: pill.active ? Font.DemiBold : Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(pill.modelData.idx, pill.modelData.output)
            }
        }
    }
}
