pragma ComponentBehavior: Bound

import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    readonly property var player: {
        const list = Mpris.players?.values ?? [];
        return list.find(p => p.playbackState === MprisPlaybackState.Playing) ?? list[0] ?? null;
    }

    title: root.player?.identity || "Медиа"
    icon: "music_note"
    cardWidth: 280

    Text {
        Layout.fillWidth: true
        text: root.player?.trackTitle || "Ничего не играет"
        color: Theme.surfaceText
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.Medium
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
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

    Text {
        Layout.fillWidth: true
        visible: !root.player
        text: "Запусти плеер, чтобы увидеть трек"
        color: Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
