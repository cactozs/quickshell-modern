pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../bar"
import "../../style"
import "../../services"

// Quick settings / control center content: two sliders and four toggle
// chips on top, then a six-tab strip (calendar, timer, stopwatch, weather,
// media, power). Not a window of its own — the bar embeds this item and
// morphs into it, same contract as Launcher.qml. Open state lives in
// QuickSettings; the bar's empty space (or `qs ipc call quicksettings
// toggleOn <output>`) toggles it. Timer/stopwatch/weather state lives here
// instead of a service singleton: the item is always instantiated, only
// its visibility flips, so a running timer survives closing the panel.
Item {
    id: root

    // Set by the embedding bar: this monitor's plate is currently the panel.
    property bool active: false

    // The embedding bar's screen — drives the workspace dots and the
    // layout/net/battery widgets mirrored at the top of the panel.
    property string screenName: ""

    // The embedding bar sizes its plate height from this.
    implicitHeight: card.implicitHeight

    readonly property int cardPadding: 14
    property int currentTab: 0

    readonly property var tabs: [
        { icon: "calendar_month" },
        { icon: "timer" },
        { icon: "stopwatch" },
        { icon: "partly_cloudy_day" },
        { icon: "music_note" },
        { icon: "power_settings_new" }
    ]

    // ---- timer engine ----
    property bool timerRunning: false
    property int timerTotalMs: 0
    property int timerBaseMs: 0
    property int timerStartMs: 0
    property int timerRemainingMs: 0

    // ---- stopwatch engine ----
    property bool swRunning: false
    property int swElapsedMs: 0
    property int swBaseMs: 0
    property int swStartMs: 0

    // ---- weather ----
    property bool weatherLoading: false
    property bool weatherFailed: false
    property string weatherTemp: ""
    property string weatherFeels: ""
    property string weatherDesc: ""
    property string weatherIcon: "partly_cloudy_day"
    property string weatherWind: ""
    property string weatherHumidity: ""
    property var weatherHours: []

    // ---- wifi / bluetooth chip state ----
    property bool wifiAvailable: true
    property bool wifiQueried: false
    property bool wifiOn: false
    property bool btAvailable: true
    property bool btQueried: false
    property bool btOn: false

    // ---- helpers ----

    function pad2(n: int): string {
        return (n < 10 ? "0" : "") + n;
    }

    function fmtMs(ms: int): string {
        const total = Math.ceil(ms / 1000);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return h > 0 ? h + ":" + root.pad2(m) + ":" + root.pad2(s) : m + ":" + root.pad2(s);
    }

    function fmtSw(ms: int): string {
        const deciseconds = Math.floor(ms / 100);
        const secs = Math.floor(deciseconds / 10);
        return Math.floor(secs / 60) + ":" + root.pad2(secs % 60) + "." + (deciseconds % 10);
    }

    function timerSet(ms: int): void {
        if (root.timerRunning)
            return;
        root.timerTotalMs = ms;
        root.timerBaseMs = ms;
        root.timerRemainingMs = ms;
    }

    function timerAdjust(deltaMs: int): void {
        if (root.timerRunning)
            return;
        root.timerSet(Math.max(0, root.timerBaseMs + deltaMs));
    }

    function timerToggle(): void {
        if (root.timerRunning) {
            root.timerBaseMs = Math.max(0, root.timerBaseMs - (Date.now() - root.timerStartMs));
            root.timerRemainingMs = root.timerBaseMs;
            root.timerRunning = false;
        } else if (root.timerBaseMs > 0) {
            root.timerStartMs = Date.now();
            root.timerRunning = true;
        }
    }

    function timerReset(): void {
        root.timerRunning = false;
        root.timerTotalMs = 0;
        root.timerBaseMs = 0;
        root.timerRemainingMs = 0;
    }

    function swToggle(): void {
        if (root.swRunning) {
            root.swBaseMs = root.swBaseMs + (Date.now() - root.swStartMs);
            root.swElapsedMs = root.swBaseMs;
            root.swRunning = false;
        } else {
            root.swStartMs = Date.now();
            root.swRunning = true;
        }
    }

    function swReset(): void {
        root.swRunning = false;
        root.swBaseMs = 0;
        root.swElapsedMs = 0;
    }

    function weatherCodeIcon(code: string): string {
        const c = parseInt(code);
        if (isNaN(c))
            return "partly_cloudy_day";
        if (c === 113)
            return "clear_day";
        if (c === 116)
            return "partly_cloudy_day";
        if (c === 119 || c === 122)
            return "cloud";
        if (c === 143 || c === 248 || c === 260)
            return "foggy";
        if (c >= 600 && c < 700)
            return "weather_snowy";
        if (c >= 200 && c < 300)
            return "thunderstorm";
        if (c >= 300)
            return "rainy";
        return "cloud";
    }

    function fetchWeather(): void {
        if (weatherProc.running)
            return;
        root.weatherLoading = true;
        root.weatherFailed = false;
        weatherProc.running = true;
    }

    function applyWeather(text: string): void {
        root.weatherLoading = false;
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            root.weatherFailed = true;
            return;
        }
        const cur = data?.current_condition?.[0];
        if (!cur) {
            root.weatherFailed = true;
            return;
        }
        root.weatherFailed = false;
        root.weatherTemp = cur.temp_C;
        root.weatherFeels = cur.FeelsLikeC;
        root.weatherDesc = cur.weatherDesc?.[0]?.value ?? "";
        root.weatherIcon = root.weatherCodeIcon(cur.weatherCode);
        root.weatherWind = cur.windspeedKmph;
        root.weatherHumidity = cur.humidity;
        // today's remaining hours, spilling into tomorrow if late
        const hourly = (data.weather?.[0]?.hourly ?? []).concat(data.weather?.[1]?.hourly ?? []);
        const nowH = new Date().getHours();
        root.weatherHours = hourly
            .filter(h => parseInt(h.time) / 100 > nowH)
            .slice(0, 3)
            .map(h => ({
                time: parseInt(h.time) / 100 + ":00",
                temp: h.tempC,
                icon: root.weatherCodeIcon(h.weatherCode)
            }));
    }

    function setWifi(enable: bool): void {
        Quickshell.execDetached(["nmcli", "radio", "wifi", enable ? "on" : "off"]);
        wifiRequery.restart();
    }

    function setBt(enable: bool): void {
        Quickshell.execDetached(["bluetoothctl", "power", enable ? "on" : "off"]);
        btRequery.restart();
    }

    // Opening this monitor's panel refreshes the lazy chip state and weather.
    onActiveChanged: {
        if (!root.active)
            return;
        if (root.wifiAvailable)
            wifiQuery.running = true;
        if (root.btAvailable)
            btQuery.running = true;
        weatherKick.restart();
    }

    Component.onCompleted: {
        wifiQuery.running = true;
        btQuery.running = true;
    }

    // ---- timers & processes ----

    Timer {
        id: timerTick

        interval: 200
        repeat: true
        running: root.timerRunning

        onTriggered: {
            root.timerRemainingMs = Math.max(0, root.timerBaseMs - (Date.now() - root.timerStartMs));
            if (root.timerRemainingMs !== 0)
                return;
            root.timerRunning = false;
            root.timerTotalMs = 0;
            root.timerBaseMs = 0;
            Quickshell.execDetached(["notify-send", "Timer", "Time is up"]);
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.swRunning

        onTriggered: root.swElapsedMs = root.swBaseMs + (Date.now() - root.swStartMs)
    }

    Timer {
        id: weatherKick

        interval: 50
        onTriggered: root.fetchWeather()
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: root.active

        onTriggered: root.fetchWeather()
    }

    Timer {
        id: wifiRequery

        interval: 700
        onTriggered: wifiQuery.running = true
    }

    Timer {
        id: btRequery

        interval: 900
        onTriggered: btQuery.running = true
    }

    Process {
        id: weatherProc

        command: ["curl", "-s", "--max-time", "6", "https://wttr.in/?format=j1"]

        stdout: StdioCollector {
            onStreamFinished: root.applyWeather(text)
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.weatherLoading = false;
                root.weatherFailed = true;
            }
        }
    }

    // `nmcli radio wifi` prints exactly "enabled" or "disabled".
    Process {
        id: wifiQuery

        command: ["nmcli", "radio", "wifi"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiQueried = true;
                root.wifiAvailable = true;
                root.wifiOn = text.trim() === "enabled";
            }
        }
    }

    Process {
        id: btQuery

        command: ["bluetoothctl", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.btQueried = true;
                root.btAvailable = true;
                root.btOn = text.includes("Powered: yes");
            }
        }
    }

    // QProcess never emits onExited for a missing binary; if nothing answered
    // in the first seconds, the tool is absent and its chip hides.
    Timer {
        interval: 4000
        running: true

        onTriggered: {
            if (!root.wifiQueried)
                root.wifiAvailable = false;
            if (!root.btQueried)
                root.btAvailable = false;
        }
    }

    // ---- content ----

    Item {
        id: card

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        implicitHeight: column.implicitHeight + root.cardPadding * 2

        Column {
            id: column

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.cardPadding
            }

            spacing: 12

            // ---- the resting bar's widgets, kept at the top of the panel ----

            RowLayout {
                width: parent.width
                spacing: 14

                Workspaces {
                    Layout.alignment: Qt.AlignVCenter
                    screenName: root.screenName
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 10
                }

                Clock {
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 10
                }

                StatusRight {
                    Layout.alignment: Qt.AlignVCenter
                    screenName: root.screenName
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.plateBorder
            }

            // ---- quick settings ----

            Column {
                id: qsBlock

                width: parent.width
                spacing: 12

                QsSlider {
                    width: parent.width
                    icon: Audio.icon
                    value: Audio.volume

                    onMoved: ratio => {
                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", ratio.toFixed(2)]);
                        if (Audio.muted)
                            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
                    }
                }

                QsSlider {
                    width: parent.width
                    icon: Brightness.icon
                    value: Brightness.percent / 100

                    onMoved: ratio => Quickshell.execDetached(["brightnessctl", "set", Math.round(ratio * 100) + "%"])
                }

                Row {
                    id: chipRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    QsChip {
                        icon: Audio.micMuted ? "mic_off" : "mic"
                        label: "Mic"
                        checked: Audio.micMuted

                        onToggled: Quickshell.execDetached(["wpctl", "set-source-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                    }

                    QsChip {
                        icon: "do_not_disturb_on"
                        label: "DND"
                        checked: Notifs.dnd

                        onToggled: Notifs.toggleDnd()
                    }

                    QsChip {
                        visible: root.wifiAvailable
                        icon: root.wifiOn ? "wifi" : "wifi_off"
                        label: "Wi-Fi"
                        checked: root.wifiOn

                        onToggled: root.setWifi(!root.wifiOn)
                    }

                    QsChip {
                        visible: root.btAvailable
                        icon: root.btOn ? "bluetooth" : "bluetooth_disabled"
                        label: "Bluetooth"
                        checked: root.btOn

                        onToggled: root.setBt(!root.btOn)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.plateBorder
            }

            // ---- tab strip ----

            Row {
                id: tabBar

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Repeater {
                    model: root.tabs

                    delegate: Rectangle {
                        id: tabBtn

                        required property int index
                        required property var modelData

                        width: 54
                        height: 36
                        radius: Theme.radiusMD
                        color: root.currentTab === tabBtn.index ? Theme.surfaceContainerHigh : "transparent"
                        scale: tabArea.pressed ? 0.94 : 1

                        Behavior on color {
                            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: tabBtn.modelData.icon
                            color: root.currentTab === tabBtn.index ? Theme.primary : Theme.onSurfaceVariant
                            font.family: Theme.iconFont
                            font.pixelSize: 20

                            Behavior on color {
                                ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: tabArea

                            anchors.fill: parent

                            onClicked: root.currentTab = tabBtn.index
                        }
                    }
                }
            }

            // ---- tabs ----

            CalendarTab {
                visible: root.currentTab === 0
            }

            TimerTab {
                visible: root.currentTab === 1
            }

            StopwatchTab {
                visible: root.currentTab === 2
            }

            WeatherTab {
                visible: root.currentTab === 3
            }

            MediaTab {
                visible: root.currentTab === 4
            }

            PowerTab {
                visible: root.currentTab === 5
            }
        }
    }

    // ---- reusable pieces ----

    // A slider row: icon, rounded track with an accent fill, percent label.
    // While dragging, dragRatio takes over the visuals so the fill follows
    // the pointer instantly; the parent's `value` binding survives.
    component QsSlider: Item {
        id: slider

        required property string icon
        property real value: 0
        property real dragRatio: -1
        signal moved(real ratio)

        readonly property real effValue: slider.dragRatio >= 0 ? slider.dragRatio : slider.value

        implicitHeight: 34

        function seek(x: real): void {
            const ratio = Math.max(0, Math.min(1, x / track.width));
            slider.dragRatio = ratio;
            slider.moved(ratio);
        }

        Text {
            id: sliderIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: slider.icon
            color: Theme.primary
            font.family: Theme.iconFont
            font.pixelSize: 18
        }

        Rectangle {
            id: track

            anchors.left: sliderIcon.right
            anchors.leftMargin: 12
            anchors.right: sliderPct.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.14)

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Math.round(parent.width * Math.max(0, Math.min(1, slider.effValue)))
                radius: parent.radius
                color: Theme.primary

                Behavior on width {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            id: sliderPct

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round(slider.effValue * 100) + "%"
            color: Theme.onSurfaceVariant
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        MouseArea {
            id: dragArea

            anchors.left: track.left
            anchors.right: track.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            onPressed: mouse => slider.seek(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    slider.seek(mouse.x);
            }
            onReleased: slider.dragRatio = -1
            onCanceled: slider.dragRatio = -1

            onWheel: wheel => {
                if (wheel.angleDelta.y === 0)
                    return;
                const base = slider.effValue;
                slider.dragRatio = -1;
                slider.moved(Math.max(0, Math.min(1, base + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))));
                wheel.accepted = true;
            }
        }
    }

    // A pill toggle chip: lights up with the container tone when checked.
    component QsChip: Rectangle {
        id: chip

        required property string icon
        required property string label
        property bool checked: false
        signal toggled()

        implicitWidth: chipContent.implicitWidth + 22
        implicitHeight: 32
        radius: 16
        color: chip.checked ? Theme.primaryContainer : Theme.surfaceContainerHigh
        border.width: chip.checked ? 1 : 0
        border.color: Theme.primary
        scale: chipArea.pressed ? 0.96 : 1

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Row {
            id: chipContent

            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                color: chip.checked ? Theme.onPrimary : Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 16
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.checked ? Theme.onPrimary : Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: chip.checked ? Font.DemiBold : Font.Medium
            }
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent

            onClicked: chip.toggled()
        }
    }

    // A small text button (presets, timer/stopwatch controls).
    component PillButton: Rectangle {
        id: pill

        required property string label
        property bool accent: false
        signal clicked()

        implicitWidth: pillLabel.implicitWidth + 24
        implicitHeight: 30
        radius: 15
        color: pill.accent ? Theme.primaryContainer : Theme.surfaceContainerHigh
        scale: pillArea.pressed ? 0.96 : 1

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Text {
            id: pillLabel

            anchors.centerIn: parent
            text: pill.label
            color: pill.accent ? Theme.onPrimary : Theme.onSurface
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: pillArea

            anchors.fill: parent

            onClicked: pill.clicked()
        }
    }

    // Month calendar, Monday-first, today ringed with the accent.
    component CalendarTab: Item {
        id: cal

        width: parent.width
        height: calCol.implicitHeight
        visible: root.currentTab === 0

        property date shownMonth: {
            const now = new Date();
            return new Date(now.getFullYear(), now.getMonth(), 1);
        }

        // 42 cells (6 weeks) so every month fits; out-of-month days dimmed.
        readonly property var cells: {
            const y = cal.shownMonth.getFullYear();
            const m = cal.shownMonth.getMonth();
            const startOffset = (new Date(y, m, 1).getDay() + 6) % 7;
            const daysInMonth = new Date(y, m + 1, 0).getDate();
            const daysInPrev = new Date(y, m, 0).getDate();
            const now = new Date();
            const isThisMonth = now.getFullYear() === y && now.getMonth() === m;
            const out = [];
            for (let i = 0; i < 42; i++) {
                const day = i - startOffset + 1;
                if (day < 1)
                    out.push({ day: daysInPrev + day, current: false, today: false });
                else if (day > daysInMonth)
                    out.push({ day: day - daysInMonth, current: false, today: false });
                else
                    out.push({ day: day, current: true, today: isThisMonth && day === now.getDate() });
            }
            return out;
        }

        function shiftMonth(delta: int): void {
            cal.shownMonth = new Date(cal.shownMonth.getFullYear(), cal.shownMonth.getMonth() + delta, 1);
        }

        Column {
            id: calCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 8

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: calPrev.right
                    anchors.right: calNext.left
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().standaloneMonthName(cal.shownMonth.getMonth(), Locale.LongFormat)
                          + " " + cal.shownMonth.getFullYear()
                    color: Theme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: calPrev

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: calPrevArea.pressed ? Theme.surfaceContainerHigh : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: calPrevArea

                        anchors.fill: parent

                        onClicked: cal.shiftMonth(-1)
                    }
                }

                Rectangle {
                    id: calNext

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: calNextArea.pressed ? Theme.surfaceContainerHigh : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: calNextArea

                        anchors.fill: parent

                        onClicked: cal.shiftMonth(1)
                    }
                }
            }

            Row {
                Repeater {
                    model: 7

                    Text {
                        required property int index

                        width: cal.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(Locale.Monday + index, Locale.ShortFormat)
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            Grid {
                columns: 7
                width: parent.width

                Repeater {
                    model: cal.cells

                    Item {
                        id: cell

                        required property int index
                        required property var modelData

                        width: cal.width / 7
                        height: 26

                        Rectangle {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            radius: 11
                            color: cell.modelData.today ? Theme.primary : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.day
                            color: cell.modelData.today ? Theme.onPrimary
                                : cell.modelData.current ? Theme.onSurface : Theme.onSurfaceVariant
                            opacity: cell.modelData.current ? 1 : 0.45
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: cell.modelData.today ? Font.DemiBold : Font.Medium
                        }
                    }
                }
            }
        }
    }

    component TimerTab: Item {
        width: parent.width
        height: timerCol.implicitHeight
        visible: root.currentTab === 1

        Column {
            id: timerCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.fmtMs(root.timerRemainingMs)
                color: root.timerRemainingMs > 0 || root.timerRunning ? Theme.onSurface : Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 34
                font.weight: Font.DemiBold
            }

            Rectangle {
                visible: root.timerTotalMs > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.7
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.14)

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: parent.width * (root.timerTotalMs > 0 ? root.timerRemainingMs / root.timerTotalMs : 0)
                    radius: parent.radius
                    color: Theme.primary
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: [1, 3, 5, 10, 25]

                    PillButton {
                        required property int modelData

                        label: modelData + " min"

                        onClicked: root.timerSet(modelData * 60000)
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                PillButton {
                    label: "-1 min"

                    onClicked: root.timerAdjust(-60000)
                }

                PillButton {
                    label: "+1 min"

                    onClicked: root.timerAdjust(60000)
                }

                PillButton {
                    accent: true
                    label: root.timerRunning ? "Pause" : "Start"
                    opacity: root.timerRunning || root.timerBaseMs > 0 ? 1 : 0.5

                    onClicked: root.timerToggle()
                }

                PillButton {
                    label: "Reset"

                    onClicked: root.timerReset()
                }
            }
        }
    }

    component StopwatchTab: Item {
        width: parent.width
        height: swCol.implicitHeight
        visible: root.currentTab === 2

        Column {
            id: swCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.fmtSw(root.swElapsedMs)
                color: Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: 34
                font.weight: Font.DemiBold
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                PillButton {
                    accent: true
                    label: root.swRunning ? "Pause" : "Start"

                    onClicked: root.swToggle()
                }

                PillButton {
                    label: "Reset"

                    onClicked: root.swReset()
                }
            }
        }
    }

    component WeatherTab: Item {
        id: weather

        width: parent.width
        height: weatherCol.implicitHeight
        visible: root.currentTab === 3

        Column {
            id: weatherCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 12

            Text {
                visible: root.weatherLoading
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Loading…"
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Column {
                visible: root.weatherFailed
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "cloud_off"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.iconFont
                    font.pixelSize: 28
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No weather data — click to retry"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            Row {
                visible: !root.weatherLoading && !root.weatherFailed && root.weatherTemp !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.weatherIcon
                    color: Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 44
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: root.weatherTemp + "°"
                        color: Theme.onSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.weatherDesc
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "Feels " + root.weatherFeels + "°"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Wind " + root.weatherWind + " km/h"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Humidity " + root.weatherHumidity + "%"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            Row {
                visible: root.weatherHours.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                Repeater {
                    model: root.weatherHours

                    Column {
                        id: hourCell

                        required property var modelData

                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hourCell.modelData.time
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hourCell.modelData.icon
                            color: Theme.primary
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hourCell.modelData.temp + "°"
                            color: Theme.onSurface
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // Offline or empty: any click on the tab re-fetches.
        MouseArea {
            anchors.fill: parent
            enabled: root.weatherFailed || root.weatherTemp === ""

            onClicked: root.fetchWeather()
        }
    }

    component MediaTab: Item {
        id: media

        width: parent.width
        height: media.player !== null ? mediaBody.height : nothingText.implicitHeight
        visible: root.currentTab === 4

        // The playing player if any, else the first player, else null.
        readonly property var player: {
            const list = Mpris.players?.values ?? [];
            return list.find(p => p.playbackState === MprisPlaybackState.Playing) ?? list[0] ?? null;
        }

        Text {
            id: nothingText

            visible: media.player === null
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            color: Theme.onSurfaceVariant
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

    Item {
        id: mediaBody

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Math.max(mediaInfo.implicitHeight, mediaControls.implicitHeight)
        visible: media.player !== null

        Column {
            id: mediaInfo

            anchors.left: parent.left
            anchors.right: mediaControls.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: media.player?.trackTitle || "Unknown track"
                color: Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: (media.player?.trackArtist ?? "") !== ""
                text: media.player?.trackArtist ?? ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Row {
            id: mediaControls

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_previous"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 24

                MouseArea {
                    anchors.fill: parent

                    onClicked: media.player?.previous()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: media.player?.playbackState === MprisPlaybackState.Playing ? "pause_circle" : "play_circle"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 30

                MouseArea {
                    anchors.fill: parent

                    onClicked: media.player?.playPause()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_next"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 24

                MouseArea {
                    anchors.fill: parent

                    onClicked: media.player?.next()
                }
            }
        }
    }
    }

    component PowerTab: Item {
        width: parent.width
        height: powerCol.implicitHeight
        visible: root.currentTab === 5

        Column {
            id: powerCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 8

            PowerButton {
                label: "Log out"
                icon: "logout"

                // niri shows its own confirmation overlay first
                onClicked: Quickshell.execDetached(["niri", "msg", "action", "quit"])
            }

            PowerButton {
                label: "Reboot"
                icon: "restart_alt"

                onClicked: Quickshell.execDetached(["systemctl", "reboot"])
            }

            PowerButton {
                label: "Power off"
                icon: "power_settings_new"
                danger: true

                onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    }

    component PowerButton: Rectangle {
        id: powerBtn

        required property string label
        required property string icon
        property bool danger: false
        signal clicked()

        width: parent.width
        height: 38
        radius: Theme.radiusMD
        color: powerBtn.danger ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
            : Theme.surfaceContainerHigh
        border.width: powerBtn.danger ? 1 : 0
        border.color: Theme.error
        scale: powerArea.pressed ? 0.98 : 1

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: powerBtn.icon
                color: powerBtn.danger ? Theme.error : Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 17
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: powerBtn.label
                color: powerBtn.danger ? Theme.error : Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: powerArea

            anchors.fill: parent

            onClicked: powerBtn.clicked()
        }
    }
}
