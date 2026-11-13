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
//
// Entrance/exit: the card grows out of / collapses into its slot (height)
// while fading, so neighbors glide after it. `shown`/`exiting` are flipped
// by NotifColumn (pool) or by exitAnimated().
Rectangle {
    id: card

    required property var model
    property bool compact: false
    property bool shown: false
    property bool exiting: false

    radius: Theme.radiusMD
    color: compact ? Theme.plate : Theme.surfaceContainerHigh
    border.width: 1
    border.color: model.critical ? Theme.error : Theme.plateBorder

    implicitHeight: bodyCol.implicitHeight + 20
    readonly property bool present: shown && !exiting
    height: present ? implicitHeight : 0
    opacity: present ? 1 : 0

    readonly property int showHeightMs: 90
    readonly property int hideHeightMs: 65
    readonly property int showOpacityMs: 55
    readonly property int hideOpacityMs: 35

    // The card unfolds into its slot, then leaves faster than it arrived.
    Behavior on height {
        NumberAnimation {
            duration: card.present ? card.showHeightMs : card.hideHeightMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.32, 0.72, 0, 1]
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: card.present ? card.showOpacityMs : card.hideOpacityMs
            easing.type: Easing.OutCubic
        }
    }

    // Animate out, then either unpopup (toast click / expired toast — the
    // write is a no-op when it already left) or dismiss (center's X).
    function exitAnimated(): void {
        if (card.exiting)
            return;
        card.exiting = true;
        exitKick.restart();
    }

    Timer {
        id: exitKick

        interval: Math.max(card.hideHeightMs, card.hideOpacityMs) + 20
        onTriggered: {
            if (card.compact)
                card.model.popup = false;
            else
                Notifs.dismiss(card.model);
            card.destroy();
        }
    }

    // Clicking a toast only hides the popup; it stays in history.
    MouseArea {
        anchors.fill: parent
        enabled: card.compact
        onClicked: card.exitAnimated()
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
                color: Theme.primary
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
                    color: Theme.primary
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
                        color: Theme.primary
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: card.exitAnimated()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: card.model.body !== ""
                text: card.model.body
                color: Theme.primary
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
                            color: Theme.primary
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
