pragma ComponentBehavior: Bound

import QtQuick
import "../../services"
import "../../style"

// Transient OSD content living inside the bar plate: while Osd.shown the bar
// widgets fade out and this fades in (same 50ms-pause choreography as the
// launcher/ribbon), then everything swaps back. Value OSDs (volume,
// brightness) show a level bar + percent; state OSDs (caps, mic, layout) a
// text label.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.icon
            color: Theme.primary
            font.family: Theme.iconFont
            font.pixelSize: 20
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Osd.value >= 0
            width: 110
            height: 8
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.14)

            Rectangle {
                width: parent.width * Osd.value
                height: parent.height
                radius: parent.radius
                color: Theme.primary

                Behavior on width {
                    NumberAnimation { duration: 45; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Osd.value >= 0
            width: 40
            text: Math.round(Osd.value * 100) + "%"
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Osd.value < 0
            text: Osd.label
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }
}
