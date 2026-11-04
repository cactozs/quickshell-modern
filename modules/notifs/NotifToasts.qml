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

    // Toasts hide while the notifications tab of the quick settings panel is
    // open on this screen — the same list is on screen and a new toast would
    // duplicate a card that is already visible.
    readonly property bool centerHere: QuickSettings.shown
        && QuickSettings.tab === Notifs.notifsTab
        && QuickSettings.screen === (Quickshell.screens[0]?.name ?? "")

    // Keep the surface mapped while the last card collapses; hide only once
    // the column has no height left, otherwise the exit animation is cut off.
    visible: (Notifs.popups.length > 0 || cards.implicitHeight > 0.5) && !centerHere
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

    NotifColumn {
        id: cards

        x: 4
        y: 4
        width: parent.width - 8
        spacing: 8

        model: Notifs.popups
        compact: true
    }
}
