pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../style"
import "../../services"

// One notification card, shared by the toasts and the center. `compact` is
// toast mode: clipped body and click-to-hide. Body text is forced to
// PlainText — it comes from arbitrary apps.
Rectangle {
    id: card

    required property var model
    property bool compact: false

    radius: Theme.radiusMD
    color: compact ? Theme.plate : Theme.surfaceContainerHigh
    border.width: 1
    border.color: model.critical ? Theme.error : Theme.plateBorder

    implicitHeight: bodyCol.implicitHeight + 20

    // Clicking a toast only hides the popup; it stays in history.
    MouseArea {
        anchors.fill: parent
        enabled: card.compact
        onClicked: card.model.popup = false
    }

    RowLayout {
        id: bodyCol

        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Item {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop

            Rectangle {
                anchors.fill: parent
                visible: card.model.image !== ""
                radius: 10
                color: Theme.plateBorder
                clip: true

                Image {
                    anchors.fill: parent
                    source: card.model.image
                    fillMode: Image.PreserveAspectCrop
                    // decode small — full-res notification images are RAM poison
                    sourceSize: Qt.size(96, 96)
                }
            }

            IconImage {
                anchors.centerIn: parent
                visible: card.model.image === "" && card.model.appIcon !== ""
                source: card.model.appIcon
                implicitSize: 28
            }

            Text {
                anchors.centerIn: parent
                visible: card.model.image === "" && card.model.appIcon === ""
                text: "notifications"
                color: Theme.onSurfaceVariant
                font.family: Theme.iconFont
                font.pixelSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: card.model.summary !== "" ? card.model.summary : card.model.appName
                    color: Theme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Notifs.dismiss(card.model)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: card.model.body !== ""
                text: card.model.body
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 12
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: card.compact ? 3 : -1
                elide: Text.ElideRight
            }

            Row {
                Layout.fillWidth: true
                visible: card.model.actions.length > 0
                spacing: 6

                Repeater {
                    model: card.model.actions

                    Rectangle {
                        id: actionBtn

                        required property var modelData

                        radius: 8
                        color: Theme.plateBorder
                        implicitWidth: actionText.implicitWidth + 20
                        implicitHeight: 24

                        Text {
                            id: actionText

                            anchors.centerIn: parent
                            text: actionBtn.modelData.text
                            color: Theme.onSurface
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: actionBtn.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
