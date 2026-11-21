pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Window
import "../../services"
import "../../style"
import "../bar"

// Lock screen content for one monitor: the wallpaper under a scrim, and the
// bar's plate morphing into the password field while the big clock slides out
// from under it. The plate copies the active bar style (island or notch) and
// keeps the bar height, so the lock frame and the real bar are the same shape.
Item {
    id: root

    readonly property int padH: 16
    readonly property int inputGap: 10
    readonly property int rowGap: 10
    readonly property int rightPad: 14
    readonly property int caretRoom: 6
    readonly property int flare: 14

    // Flipped once the surface has had a frame to show the bar replica; also
    // flipped back on unlock so the collapse plays before the lock is released.
    property bool expanded: false

    // Fallback under the wallpaper while it decodes.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Image {
        id: wallpaperImage

        // Fall back to another known wallpaper if the current file is missing
        // (awww can still report a path that was deleted from disk).
        property bool useFallback: false
        readonly property string primary: Wallpaper.current === "" ? "" : "file://" + Wallpaper.current
        readonly property string fallback: {
            const list = Wallpaper.list;
            for (let i = 0; i < list.length; i++) {
                if (list[i] !== Wallpaper.current)
                    return "file://" + list[i];
            }
            return "";
        }

        anchors.fill: parent
        source: useFallback ? fallback : primary
        // A 6K source decodes to ~97 MB; bound it to the physical screen size.
        sourceSize.width: root.width * Screen.devicePixelRatio
        sourceSize.height: root.height * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false

        onPrimaryChanged: useFallback = false
        onStatusChanged: {
            if (status === Image.Error && !useFallback && fallback !== "")
                useFallback = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }

    // Clicking anywhere puts the caret back into the field.
    MouseArea {
        anchors.fill: parent
        onClicked: password.forceActiveFocus()
    }

    SystemClock {
        id: bigClock
        precision: SystemClock.Minutes
    }

    // The big clock is clipped at the plate's bottom edge: at rest it sits
    // entirely above the clip, so the slide reads as the clock crawling out.
    Item {
        id: clockReveal

        anchors.horizontalCenter: parent.horizontalCenter
        // The plate height is constant, so this needs no reference to it.
        y: BarState.topMargin + Theme.barHeight
        width: root.width
        height: bigClockBlock.implicitHeight + 24
        clip: true

        ColumnLayout {
            id: bigClockBlock

            anchors.horizontalCenter: parent.horizontalCenter
            y: root.expanded ? 16 : -height
            spacing: 2

            Behavior on y {
                SequentialAnimation {
                    PauseAnimation { duration: root.expanded ? 70 : 0 }
                    NumberAnimation {
                        duration: root.expanded ? 220 : 130
                        easing.type: Easing.OutQuint
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(bigClock.date, "HH:mm")
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 84
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(bigClock.date, "dddd, d MMMM")
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 15
            }
        }
    }

    // The bar's resting plate, reproduced with the same geometry as Bar.qml:
    // island = floating pill with a border, notch = flush plate with flare
    // wings and a stroked outline. It then grows into the password field.
    Item {
        id: island

        // The field is only as wide as its content: no placeholder, so an
        // empty field collapses to the lock icon and the layout chip.
        readonly property int fieldMinWidth: 104
        readonly property int fieldMaxWidth: Math.max(fieldMinWidth,
            Math.min(root.width - 48, 520))
        readonly property int fieldChromeWidth: root.padH + lockIcon.implicitWidth
            + root.inputGap + root.rowGap + rightRow.implicitWidth + root.rightPad
        readonly property int fieldTextWidth: root.caretRoom + Math.ceil(Math.max(
            password.implicitWidth, errorLabel.visible ? errorLabel.implicitWidth : 0))
        readonly property int fieldWidth: Math.max(fieldMinWidth,
            Math.min(fieldMaxWidth, fieldChromeWidth + fieldTextWidth))

        anchors.horizontalCenter: parent.horizontalCenter
        y: BarState.topMargin
        width: root.expanded ? fieldWidth : restClock.implicitWidth + root.padH * 2
        height: Theme.barHeight
        clip: true

        Behavior on width {
            NumberAnimation {
                // Short enough that the field follows typing without lag;
                // the collapse keeps the calmer bar timing.
                duration: root.expanded ? 120 : 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.32, 0.72, 0, 1]
            }
        }

        Rectangle {
            // Notch: drawn one radius taller and shifted up, so the top
            // rounding is clipped away and the plate meets the top edge.
            y: BarState.island ? 0 : -Theme.radiusLG
            width: parent.width
            height: parent.height + (BarState.island ? 0 : Theme.radiusLG)
            radius: BarState.island ? Theme.barIslandRadius : Theme.radiusLG
            color: Theme.plate
            border.width: BarState.island ? 1 : 0
            border.color: Theme.plateBorder
        }

        Clock {
            id: restClock

            anchors.centerIn: parent
            opacity: root.expanded ? 0 : 1
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
            }
        }

        Item {
            id: inputRow

            anchors.fill: parent
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.expanded ? 70 : 0 }
                    NumberAnimation {
                        duration: root.expanded ? 120 : 50
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: lockIcon

                anchors.left: parent.left
                anchors.leftMargin: root.padH
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                color: password.activeFocus ? Theme.primary : Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: 20

                Behavior on color {
                    ColorAnimation { duration: 70; easing.type: Easing.OutCubic }
                }
            }

            TextInput {
                id: password

                anchors.left: lockIcon.right
                anchors.leftMargin: root.inputGap
                anchors.right: parent.right
                anchors.rightMargin: root.rightPad + rightRow.implicitWidth
                    + (rightRow.implicitWidth > 0 ? root.rowGap : 0)
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                echoMode: TextInput.Password
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 14
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryText
                // The singleton is the shared state; onTextEdited only fires
                // on user input, so reset() clears the field without a loop.
                text: LockAuth.password
                onTextEdited: LockAuth.password = text
                onAccepted: LockAuth.tryUnlock()
            }

            // No placeholder: an empty field stays compact. Errors still show
            // here, red, and the field widens just enough to fit them.
            Text {
                id: errorLabel

                anchors.left: password.left
                anchors.right: password.right
                anchors.verticalCenter: parent.verticalCenter
                visible: LockAuth.error !== ""
                text: LockAuth.error
                color: Theme.error
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.rightMargin: root.rightPad
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.rowGap

                // Caps state is invisible while locked (the OSD lives in the
                // bar behind the lock surface), so mirror it as an icon only.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "keyboard_capslock"
                    color: Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    opacity: CapsLock.capsOn ? 1 : 0
                    visible: opacity > 0.001

                    Behavior on opacity {
                        NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                    }
                }

                // Same globe + short name as the bar's layout chip; click
                // cycles the layout so a locked session can still switch.
                Item {
                    id: layoutChip

                    visible: Niri.currentLayout !== ""
                    implicitWidth: layoutRow.implicitWidth
                    implicitHeight: layoutRow.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: layoutRow

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "language"
                            color: Theme.primary
                            font.family: Theme.iconFont
                            font.pixelSize: 17
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Niri.currentLayout.toUpperCase()
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
                            password.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    // Notch only: the flare wings and the continuous outline from Bar.qml.
    // They sit outside the clipped plate and follow its animated width.
    Shape {
        anchors.right: island.left
        y: island.y
        width: root.flare
        height: root.flare
        antialiasing: true
        visible: !BarState.island

        ShapePath {
            fillColor: Theme.plate
            strokeWidth: -1

            startX: 0
            startY: 0
            PathLine { x: root.flare; y: 0 }
            PathLine { x: root.flare; y: root.flare }
            PathArc {
                x: 0
                y: 0
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Counterclockwise
            }
        }
    }

    Shape {
        anchors.left: island.right
        anchors.leftMargin: -1
        y: island.y
        width: root.flare + 1
        height: root.flare
        antialiasing: true
        visible: !BarState.island

        ShapePath {
            fillColor: Theme.plate
            strokeWidth: -1

            startX: root.flare
            startY: 0
            PathLine { x: 0; y: 0 }
            PathLine { x: 0; y: root.flare }
            PathArc {
                x: root.flare
                y: 0
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Clockwise
            }
        }
    }

    Shape {
        id: outline

        anchors.left: island.left
        anchors.leftMargin: -root.flare
        y: island.y
        width: island.width + root.flare * 2
        height: island.height
        antialiasing: true
        visible: !BarState.island

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.plateBorder
            strokeWidth: 1

            startX: 0
            startY: 0
            PathArc {
                x: root.flare
                y: root.flare
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Clockwise
            }
            PathLine { x: root.flare; y: outline.height - Theme.radiusLG }
            PathArc {
                x: root.flare + Theme.radiusLG
                y: outline.height
                radiusX: Theme.radiusLG
                radiusY: Theme.radiusLG
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.width - root.flare - Theme.radiusLG; y: outline.height }
            PathArc {
                x: outline.width - root.flare
                y: outline.height - Theme.radiusLG
                radiusX: Theme.radiusLG
                radiusY: Theme.radiusLG
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.width - root.flare; y: root.flare }
            PathArc {
                x: outline.width
                y: 0
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Clockwise
            }
        }
    }

    // The surface exists before the compositor maps it; let the bar replica
    // render first, then morph. Focus is kicked a little earlier so typing
    // works during the reveal.
    Timer {
        id: expandTimer
        interval: 80
        running: true
        onTriggered: root.expanded = true
    }

    Timer {
        id: focusKick
        interval: 50
        running: true
        onTriggered: password.forceActiveFocus()
    }

    // Wrong password: a short horizontal shake, house-style small geometry.
    SequentialAnimation {
        id: shake

        NumberAnimation { target: island; property: "anchors.horizontalCenterOffset"; to: -12; duration: 35; easing.type: Easing.OutCubic }
        NumberAnimation { target: island; property: "anchors.horizontalCenterOffset"; to: 10; duration: 35; easing.type: Easing.OutCubic }
        NumberAnimation { target: island; property: "anchors.horizontalCenterOffset"; to: -6; duration: 35; easing.type: Easing.OutCubic }
        NumberAnimation { target: island; property: "anchors.horizontalCenterOffset"; to: 0; duration: 35; easing.type: Easing.OutCubic }
    }

    Connections {
        target: LockAuth

        function onErrorChanged(): void {
            if (LockAuth.error !== "")
                shake.start();
        }

        function onUnlocked(): void {
            // Collapse back into the bar before LockScreen releases the lock.
            root.expanded = false;
        }
    }
}
