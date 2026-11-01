pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../style"
import "../../services"
import "."

// Popup toasts: one window on the primary screen, top-right under the bar.
// The whole window is masked to the card column, so gaps pass clicks through
// to whatever sits below.
PanelWindow {
    id: root

    // Toasts hide while the center is open on this screen — both windows
    // drop from the same spot and would overlap.
    readonly property bool centerHere: Notifs.shown && Notifs.screen === (Quickshell.screens[0]?.name ?? "")

    visible: Notifs.popups.length > 0 && !centerHere
    screen: Quickshell.screens[0] ?? null

    anchors {
        top: true
        right: true
    }

    margins {
        top: 6
        right: Theme.barSideMargin
    }

    implicitWidth: 372
    implicitHeight: cards.implicitHeight + 8

    color: "transparent"
    WlrLayershell.namespace: "quickshell:notif-toasts"

    // floating toasts reserve no space either
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        item: cards
    }

    Column {
        id: cards

        x: 4
        y: 4
        width: parent.width - 8
        spacing: 8

        Repeater {
            model: Notifs.popups

            NotifCard {
                required property var modelData

                model: modelData
                compact: true
                width: parent.width
            }
        }
    }
}
