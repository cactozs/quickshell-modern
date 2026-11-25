pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../../../style"

Rectangle {
    id: root

    readonly property var player: {
        const list = Mpris.players?.values ?? [];
        return list.find(p => p.playbackState === MprisPlaybackState.Playing) ?? list[0] ?? null;
    }

    implicitWidth: 260
    implicitHeight: content.implicitHeight + 28
    radius: Theme.radiusXL
    color: Theme.plate
    border.width: 1
    border.color: Theme.plateBorder

    ColumnLayout {
        id: content

        anchors {
            fill: parent
            margins: 14
        }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "music_note"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 18
            }

            Text {
                Layout.fillWidth: true
                text: root.player ? (root.player.identity || "Медиа") : "Медиа"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.player?.trackTitle || "Ничего не играет"
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: !!root.player?.trackArtist
            text: root.player?.trackArtist ?? ""
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
