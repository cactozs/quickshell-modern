pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../style"
import "../../services"
import "."

// Click-outside scrim for the launcher AND the notification center (the two
// are mutually exclusive). Covers everything below the bar strip — the bar
// window keeps its own input — and is fully transparent; a click anywhere on
// it closes whichever panel is open. The notif plate lives INSIDE this
// window (top-right) so two same-layer windows never have to stack against
// each other; a click-eater MouseArea on the plate keeps card clicks from
// reaching the scrim.
PanelWindow {
    id: root

    readonly property int maxListHeight: Math.round((root.screen?.height ?? 900) * 0.55)

    visible: Notifs.shown || LauncherState.shown
    screen: Quickshell.screens.find(s => s.name === (LauncherState.shown ? LauncherState.screen : Notifs.screen)) ?? null

    anchors {
        left: true
        right: true
        bottom: true
    }

    // Height stops at the bar strip: the bar's exclusive zone (barHeight +
    // barMargin) pushes the top edge down to exactly that line.
    implicitHeight: (root.screen?.height ?? 900) - Theme.barHeight - Theme.barMargin

    color: "transparent"
    WlrLayershell.namespace: "quickshell:panel-scrim"

    // A transparent overlay must not reserve space, or niri squeezes every
    // normal window into the strip between the bar and the scrim.
    exclusionMode: ExclusionMode.Ignore

    // The vertical strip under the LAUNCHER plate is subtracted from the
    // input mask: the scrim maps after the bar, so without the hole it would
    // sit on top of the grown launcher plate and swallow its clicks. The
    // notif plate lives inside THIS window, so it needs no hole (a hole
    // would punch out its own input too). The two panels are mutually
    // exclusive, so the hole is simply zero-sized while the center is open.
    readonly property int holeW: LauncherState.shown ? LauncherState.plateWidth : 0
    readonly property int holeX: LauncherState.shown
        ? Math.round((root.width - root.holeW) / 2) : 0

    mask: Region {
        id: scrimMask

        width: root.width
        height: root.height

        Region {
            x: root.holeX
            y: 0
            width: root.holeW
            height: scrimMask.height
            intersection: Intersection.Subtract
        }
    }

    MouseArea {
        anchors.fill: parent

        onClicked: {
            if (LauncherState.shown)
                LauncherState.close();
            else
                Notifs.shown = false;
        }
    }

    // ---- notification center plate ----

    Item {
        id: plate

        visible: Notifs.shown
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 6
            rightMargin: Theme.barSideMargin
        }
        width: 400
        height: headerRow.implicitHeight + 10 + Math.min(listArea.contentHeight, root.maxListHeight) + 34

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLG
            color: Theme.plate
            border.width: 1
            border.color: Theme.plateBorder
        }

        // Click eater: clicks on plate padding or text must not fall through
        // to the scrim and close the center.
        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            id: headerRow

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 12
            }

            Text {
                Layout.fillWidth: true
                text: "Notifications"
                color: Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Text {
                text: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                color: Notifs.dnd ? Theme.primary : Theme.onSurfaceVariant
                font.family: Theme.iconFont
                font.pixelSize: 17

                MouseArea {
                    anchors.fill: parent
                    onClicked: Notifs.toggleDnd()
                }
            }

            Item {
                width: 10
            }

            Text {
                text: "delete_sweep"
                color: Theme.onSurfaceVariant
                font.family: Theme.iconFont
                font.pixelSize: 17

                MouseArea {
                    anchors.fill: parent
                    onClicked: Notifs.clear()
                }
            }
        }

        Flickable {
            id: listArea

            anchors {
                top: headerRow.bottom
                topMargin: 10
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 12
                bottomMargin: 14
            }

            contentHeight: cardsCol.implicitHeight
            clip: true

            Column {
                id: cardsCol

                width: listArea.width
                spacing: 8

                Text {
                    visible: Notifs.list.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "All caught up"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                Repeater {
                    model: Notifs.list

                    NotifCard {
                        required property var modelData

                        model: modelData
                        width: cardsCol.width
                    }
                }
            }
        }
    }
}
