pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../style"

Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property int cardWidth: 240
    default property alias content: body.data

    implicitWidth: cardWidth
    implicitHeight: col.implicitHeight + 28
    radius: Theme.radiusXL
    color: Theme.plate
    border.width: 1
    border.color: Theme.plateBorder

    ColumnLayout {
        id: col

        anchors {
            fill: parent
            margins: 14
        }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.title !== "" || root.icon !== ""

            Text {
                visible: root.icon !== ""
                text: root.icon
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 16
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 6
        }
    }
}
