pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../style"

// Shared desktop widget shell: dark HUD plate, accent icon tile, optional
// right-side status badge. Widgets add their own body through the default alias.
Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property string badge: ""
    property color accent: Theme.primary
    property int cardWidth: 280
    property bool hovered: false
    property bool dragging: false
    default property alias content: body.data

    implicitWidth: cardWidth
    implicitHeight: col.implicitHeight + 32
    radius: Theme.radiusWidget
    color: Theme.plate
    border.width: 1
    border.color: root.hovered || root.dragging ? Theme.alpha(root.accent, 0.42) : Theme.plateBorder

    Behavior on border.color {
        ColorAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    // Soft top sheen so the plate reads as a surface, not a flat hole.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.045) }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }

    Rectangle {
        x: 18
        y: 0
        width: parent.width - 36
        height: 1
        color: Theme.widgetHighlight
    }

    ColumnLayout {
        id: col

        anchors {
            fill: parent
            margins: 16
        }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.title !== "" || root.icon !== ""

            Rectangle {
                width: 30
                height: 30
                radius: 9
                color: Theme.alpha(root.accent, root.hovered || root.dragging ? 0.24 : 0.14)

                Behavior on color {
                    ColorAnimation { duration: 110; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    color: root.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 17
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.badge !== ""
                implicitWidth: badgeText.implicitWidth + 14
                implicitHeight: 20
                radius: 10
                color: Theme.surfaceContainerHigh

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.badge
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 8
        }
    }
}
