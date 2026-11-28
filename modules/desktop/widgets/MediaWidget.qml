pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    readonly property var player: {
        const list = Mpris.players?.values ?? [];
        return list.find(p => p.playbackState === MprisPlaybackState.Playing) ?? list[0] ?? null;
    }
    readonly property bool playing: root.player?.playbackState === MprisPlaybackState.Playing
    readonly property real length: Number(root.player?.length ?? 0)
    readonly property string stateText: !root.player ? ""
        : root.playing ? "Играет"
        : root.player.playbackState === MprisPlaybackState.Paused ? "Пауза" : "Стоп"

    property real pos: 0

    title: root.player?.identity || "Медиа"
    icon: "music_note"
    accent: Theme.tertiary
    cardWidth: 340
    badge: root.stateText

    onPlayerChanged: root.pos = Number(root.player?.position ?? 0)

    Connections {
        target: root.player

        function onPositionChanged(): void {
            root.pos = Number(root.player?.position ?? 0);
        }

        function onTrackTitleChanged(): void {
            root.pos = Number(root.player?.position ?? 0);
        }
    }

    // MPRIS only reports position on seeks; interpolate while playing so the
    // progress bar actually moves.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing

        onTriggered: {
            if (root.length > 0)
                root.pos = Math.min(root.length, root.pos + 1);
        }
    }

    function fmtTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const mm = (m < 10 ? "0" : "") + m;
        const ss = (s < 10 ? "0" : "") + s;
        return h > 0 ? h + ":" + mm + ":" + ss : m + ":" + ss;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Item {
            width: 92
            height: 92

            Rectangle {
                anchors.fill: parent
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.tertiary, 0.22) }
                    GradientStop { position: 1.0; color: Theme.surfaceContainerHigh }
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: 18
                color: "transparent"

                Image {
                    id: art

                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: root.player?.trackArtUrl ?? ""
                    sourceSize: Qt.size(184, 184)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !art.visible
                text: "music_note"
                color: Theme.alpha(Theme.tertiary, 0.55)
                font.family: Theme.iconFont
                font.pixelSize: 38
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Ничего не играет"
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                maximumLineCount: 2
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

            Text {
                Layout.fillWidth: true
                visible: !!root.player?.trackAlbum
                text: root.player?.trackAlbum ?? ""
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: !root.player
                text: "Запусти плеер, чтобы увидеть трек"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 8
        visible: !!root.player && root.length > 0

        Text {
            text: root.fmtTime(root.pos)
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Theme.surfaceContainerHigh

            Rectangle {
                width: parent.width * (root.length > 0 ? Math.max(0, Math.min(1, root.pos / root.length)) : 0)
                height: parent.height
                radius: parent.radius
                color: Theme.tertiary
            }
        }

        Text {
            text: root.fmtTime(root.length)
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
