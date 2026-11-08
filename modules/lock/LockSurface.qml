pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../services"
import "../../style"

// Lock screen content for one monitor, in the shell's own language: the
// wallpaper under a scrim, a big top-center clock, and the OLED password
// pill at the bottom. Every surface shares services/LockAuth.
Item {
    id: root

    // Fallback under the wallpaper while it decodes.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Image {
        anchors.fill: parent
        source: Wallpaper.current === "" ? "" : "file://" + Wallpaper.current
        // A 6K source decodes to ~97 MB; bound it to the physical screen size.
        sourceSize.width: root.width * Screen.devicePixelRatio
        sourceSize.height: root.height * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
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
        id: clock
        precision: SystemClock.Minutes
    }

    // Everything animated fades in once per lock: the surface is created
    // fresh on every session lock, so a run-once animation needs no state.
    Item {
        id: content

        anchors.fill: parent
        opacity: 0

        Component.onCompleted: entrance.start()

        SequentialAnimation {
            id: entrance

            NumberAnimation {
                target: content
                property: "opacity"
                to: 1
                duration: 240
                easing.type: Easing.OutQuint
            }
        }

        // ---- clock block -------------------------------------------------

        ColumnLayout {
            id: clockBlock

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.14
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 84
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 15
            }
        }

        // ---- bottom block ------------------------------------------------

        ColumnLayout {
            id: bottomBlock

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 72
            spacing: 10

            // Caps state is invisible while locked (the OSD lives in the bar
            // behind the lock surface), so mirror it here.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 32
                implicitWidth: capsRow.implicitWidth + 24
                radius: height / 2
                color: Theme.plate
                border.width: 1
                border.color: Theme.plateBorder
                opacity: CapsLock.capsOn ? 1 : 0
                visible: opacity > 0.001

                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Row {
                    id: capsRow

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "keyboard_capslock"
                        color: Theme.primary
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Caps Lock"
                        color: Theme.surfaceText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Quickshell.env("USER")
                    color: Theme.surfaceText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Niri.currentLayout !== ""
                    text: "· " + Niri.currentLayout.toUpperCase()
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            // ---- password pill --------------------------------------------

            Rectangle {
                id: pill

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(root.width - 48, 360)
                Layout.preferredHeight: 48
                radius: height / 2
                color: Theme.plate
                border.width: 1
                border.color: password.activeFocus ? Theme.primary : Theme.plateBorder

                Behavior on border.color {
                    ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                // Inner backing: the lock icon is a fixed prefix and the
                // echoed dots grow to its right.
                Rectangle {
                    id: fieldBack

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    radius: height / 2
                    color: Theme.surfaceContainerHighest

                    Text {
                        id: lockIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "lock"
                        color: password.activeFocus ? Theme.primary : Theme.surfaceVariantText
                        font.family: Theme.iconFont
                        font.pixelSize: 20

                        Behavior on color {
                            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        id: placeholderText

                        anchors.left: lockIcon.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text.length === 0
                        text: "Enter password"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    TextInput {
                        id: password

                        anchors.left: lockIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 16
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
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: LockAuth.error !== ""
                text: LockAuth.error
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    // The surface exists before the compositor maps it; give the field focus
    // once the window is actually there.
    Timer {
        id: focusKick
        interval: 50
        running: true
        onTriggered: password.forceActiveFocus()
    }

    // Wrong password: a short horizontal shake, house-style small geometry.
    // The block shakes, not the pill: layout-managed children have no
    // horizontalCenter anchor to offset.
    SequentialAnimation {
        id: shake

        NumberAnimation { target: bottomBlock; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50; easing.type: Easing.OutCubic }
        NumberAnimation { target: bottomBlock; property: "anchors.horizontalCenterOffset"; to: 10; duration: 50; easing.type: Easing.OutCubic }
        NumberAnimation { target: bottomBlock; property: "anchors.horizontalCenterOffset"; to: -6; duration: 50; easing.type: Easing.OutCubic }
        NumberAnimation { target: bottomBlock; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50; easing.type: Easing.OutCubic }
    }

    Connections {
        target: LockAuth

        function onErrorChanged(): void {
            if (LockAuth.error !== "")
                shake.start();
        }
    }
}
