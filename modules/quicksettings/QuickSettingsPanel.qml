pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../bar"
import "../notifs"
import "../../style"
import "../../services"

// Quick settings / control center content: two sliders and four chips on
// top (the Wi-Fi chip opens the networks view instead of toggling), then a
// ten-tab strip (calendar, timer, stopwatch, weather, media, notifications,
// power, system, tray, app colors) plus the chip-opened networks view. Not a window of its own — the bar embeds this item and
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

    // Esc closes, like the launcher.
    Keys.onEscapePressed: QuickSettings.close()
    Keys.onPressed: event => {
        if (!(event.modifiers & Qt.ControlModifier))
            return;
        const direction = event.key === Qt.Key_PageDown ? 1
            : event.key === Qt.Key_PageUp ? -1 : 0;
        if (direction === 0)
            return;
        const visibleTabs = root.tabs.map(t => t.tab);
        const index = visibleTabs.indexOf(root.currentTab);
        root.currentTab = visibleTabs[(index + direction + visibleTabs.length) % visibleTabs.length];
        event.accepted = true;
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure Esc
    // works either way.
    focus: root.active

    readonly property int cardPadding: 14

    // Selected tab, mirrored into the QuickSettings service so IPC (and
    // Notifs.toggleCenter) can open the panel directly on a tab.
    property int currentTab: QuickSettings.tab

    // Index in `tabs`, not the raw tab id: the Wi-Fi view (7) has no button
    // in the strip, so the indicator hides there.
    readonly property int activeTabIndex: root.tabs.findIndex(t => t.tab === root.currentTab)

    onCurrentTabChanged: {
        QuickSettings.tab = currentTab;
        if (currentTab !== 10)
            trayTab.reset();
        if (currentTab === 7) {
            if (root.active)
                root.wifiRefresh();
        } else {
            // leaving the view hides the password input
            root.wifiPasswordFor = "";
        }
    }

    // Leaving the password field drops its error.
    onWifiPasswordForChanged: {
        if (root.wifiPasswordFor === "")
            root.wifiError = "";
    }

    // Views: 0-6 and 9-10 are the strip tabs, 7 is the chip-opened networks
    // view, 8 is the bar/app-color settings. The palette icon stores its tab
    // number explicitly so the Wi-Fi view keeps 7 without appearing in the
    // strip.
    readonly property var tabs: [
        { icon: "calendar_month", tab: 0 },
        { icon: "timer", tab: 1 },
        { icon: "stopwatch", tab: 2 },
        { icon: "partly_cloudy_day", tab: 3 },
        { icon: "music_note", tab: 4 },
        { icon: "notifications", tab: 5 },
        { icon: "power_settings_new", tab: 6 },
        { icon: "monitoring", tab: 9 },
        { icon: "inbox", tab: 10 },
        { icon: "palette", tab: 8 }
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
    property var weatherCoords: null

    // ---- wifi / bluetooth chip state ----
    property bool wifiAvailable: true
    property bool wifiQueried: false
    property bool wifiOn: false
    property bool btAvailable: true
    property bool btQueried: false
    property bool btOn: false

    // ---- wifi networks view state (the chip's view, tab 7) ----
    property var wifiNetworks: []        // scanned APs: {ssid, signal, secured, inUse}
    property var wifiSaved: []           // saved profiles: {name}
    property bool wifiScanning: false
    property string wifiActiveIface: ""  // connected interface, for disconnect
    property string wifiPasswordFor: ""  // ssid awaiting a password; shows the input
    property string wifiConnecting: ""
    property string wifiError: ""

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

    // WMO weather codes used by Open-Meteo.
    function weatherCodeInfo(code: var): var {
        const c = parseInt(code);
        if (c === 0)
            return { icon: "clear_day", desc: "Clear" };
        if (c === 1)
            return { icon: "partly_cloudy_day", desc: "Mainly clear" };
        if (c === 2)
            return { icon: "partly_cloudy_day", desc: "Partly cloudy" };
        if (c === 3)
            return { icon: "cloud", desc: "Overcast" };
        if (c === 45 || c === 48)
            return { icon: "foggy", desc: "Fog" };
        if (c >= 51 && c <= 57)
            return { icon: "rainy", desc: "Drizzle" };
        if (c >= 61 && c <= 67)
            return { icon: "rainy", desc: "Rain" };
        if (c >= 71 && c <= 77)
            return { icon: "weather_snowy", desc: "Snow" };
        if (c >= 80 && c <= 82)
            return { icon: "rainy", desc: "Showers" };
        if (c >= 85 && c <= 86)
            return { icon: "weather_snowy", desc: "Snow showers" };
        if (c >= 95)
            return { icon: "thunderstorm", desc: "Thunderstorm" };
        return { icon: "partly_cloudy_day", desc: "" };
    }

    function fetchWeather(): void {
        if (geoProc.running || weatherProc.running)
            return;
        root.weatherLoading = true;
        root.weatherFailed = false;
        weatherTimeout.restart();
        if (root.weatherCoords !== null)
            root.startWeatherFetch();
        else
            geoProc.running = true;
    }

    function startWeatherFetch(): void {
        const c = root.weatherCoords;
        weatherProc.command = ["curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + c.lat
            + "&longitude=" + c.lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code&timezone=auto&forecast_days=2"];
        weatherTimeout.restart();
        weatherProc.running = true;
    }

    function applyGeo(text: string): void {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            root.weatherLoading = false;
            root.weatherFailed = true;
            weatherTimeout.stop();
            return;
        }
        if (!data?.success || data.latitude === undefined || data.longitude === undefined) {
            root.weatherLoading = false;
            root.weatherFailed = true;
            weatherTimeout.stop();
            return;
        }
        root.weatherCoords = { lat: data.latitude, lon: data.longitude };
        root.startWeatherFetch();
    }

    function applyWeather(text: string): void {
        root.weatherLoading = false;
        weatherTimeout.stop();
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            root.weatherFailed = true;
            return;
        }
        const cur = data?.current;
        if (!cur) {
            root.weatherFailed = true;
            return;
        }
        const info = root.weatherCodeInfo(cur.weather_code);
        root.weatherFailed = false;
        root.weatherTemp = Math.round(cur.temperature_2m);
        root.weatherFeels = Math.round(cur.apparent_temperature);
        root.weatherDesc = info.desc;
        root.weatherIcon = info.icon;
        root.weatherWind = Math.round(cur.wind_speed_10m);
        root.weatherHumidity = cur.relative_humidity_2m;
        // next hours from now, spilling into tomorrow if late
        const hourly = data.hourly ?? {};
        const times = hourly.time ?? [];
        root.weatherHours = times
            .map((time, i) => ({ time, i }))
            .filter(h => h.time > cur.time)
            .slice(0, 3)
            .map(h => ({
                time: h.time.substring(11, 16),
                temp: Math.round(hourly.temperature_2m[h.i]),
                icon: root.weatherCodeInfo(hourly.weather_code[h.i]).icon
            }));
    }

    function setWifi(enable: bool): void {
        Quickshell.execDetached(["nmcli", "radio", "wifi", enable ? "on" : "off"]);
        wifiRequery.restart();
        wifiKick.restart();
    }

    function setBt(enable: bool): void {
        Quickshell.execDetached(["bluetoothctl", "power", enable ? "on" : "off"]);
        btRequery.restart();
    }

    // ---- wifi networks view ----

    function wifiSignalIcon(signal: int): string {
        // no wifi_3_bar glyph in Material Symbols Rounded; network_wifi_3_bar is
        return signal > 80 ? "wifi" : signal > 60 ? "network_wifi_3_bar"
            : signal > 35 ? "wifi_2_bar" : "wifi_1_bar";
    }

    function wifiRefresh(): void {
        if (root.wifiScanning)
            return;
        root.wifiScanning = true;
        wifiScanProc.running = true;
        wifiMetaProc.running = true;
    }

    function wifiConnectTo(ssid: string, password: string): void {
        if (root.wifiConnecting !== "")
            return;
        root.wifiConnecting = ssid;
        root.wifiError = "";
        // shortcut: the password travels on argv and is visible in ps for the
        // seconds nmcli runs; upgrade when Process gains stdin support
        const cmd = ["nmcli", "device", "wifi", "connect", ssid];
        if (password !== "")
            cmd.push("password", password);
        wifiConnectProc.command = cmd;
        wifiConnectProc.running = true;
    }

    function wifiDisconnect(): void {
        if (root.wifiActiveIface === "")
            return;
        Quickshell.execDetached(["nmcli", "device", "disconnect", root.wifiActiveIface]);
        wifiKick.restart();
    }

    function wifiForget(name: string): void {
        Quickshell.execDetached(["nmcli", "connection", "delete", name]);
        wifiKick.restart();
    }

    function wifiClicked(net: var): void {
        if (net.inUse || root.wifiConnecting !== "")
            return;
        root.wifiError = "";
        if (net.secured)
            root.wifiPasswordFor = net.ssid;
        else
            root.wifiConnectTo(net.ssid, "");
    }

    // nmcli terse output escapes ":" and "\" as "\:" and "\\". IN-USE, SIGNAL
    // and SECURITY never contain colons, so the first two and the last colon
    // are fixed boundaries and everything between them is the SSID.
    function applyScan(text: string): void {
        const best = {};
        for (const line of text.split("\n")) {
            const i1 = line.indexOf(":");
            const i2 = line.indexOf(":", i1 + 1);
            const i3 = line.lastIndexOf(":");
            if (i1 < 1 || i2 < 0 || i3 <= i2)
                continue;
            const ssid = line.slice(i2 + 1, i3).replace(/\\(.)/g, "$1");
            if (ssid === "")
                continue; // hidden AP
            const net = {
                inUse: line.slice(0, i1) === "*",
                signal: parseInt(line.slice(i1 + 1, i2)) || 0,
                ssid: ssid,
                secured: line.slice(i3 + 1) !== ""
            };
            const old = best[ssid];
            // the in-use BSSID wins over a stronger sibling of the same ssid
            if (!old
                || (net.inUse && !old.inUse)
                || (!old.inUse && !net.inUse && net.signal > old.signal))
                best[ssid] = net;
        }
        root.wifiNetworks = Object.values(best).sort((a, b) =>
            a.inUse !== b.inUse ? (a.inUse ? -1 : 1) : b.signal - a.signal);
    }

    // One `connection show` query yields both the saved wireless profiles and
    // the active one (only an active profile has its DEVICE filled in).
    function applyMeta(text: string): void {
        const saved = [];
        let iface = "";
        for (const line of text.split("\n")) {
            const i3 = line.lastIndexOf(":");
            const i2 = line.lastIndexOf(":", i3 - 1);
            if (i2 < 0 || i3 <= i2)
                continue;
            if (!line.slice(i2 + 1, i3).includes("wireless"))
                continue;
            saved.push({ name: line.slice(0, i2).replace(/\\(.)/g, "$1") });
            const device = line.slice(i3 + 1);
            if (device !== "" && iface === "")
                iface = device;
        }
        root.wifiSaved = saved;
        root.wifiActiveIface = iface;
    }

    // Opening this monitor's panel refreshes the lazy chip state and weather;
    // closing drops the transient wifi view state (and the keyboard grab).
    onActiveChanged: {
        if (root.active) {
            if (root.wifiAvailable)
                wifiQuery.running = true;
            if (root.btAvailable)
                btQuery.running = true;
            weatherKick.restart();
            focusKick.restart();
            if (root.currentTab === 7)
                root.wifiRefresh();
        } else {
            root.wifiPasswordFor = "";
            root.wifiError = "";
            trayTab.reset();
        }
    }

    // Layer surfaces take a beat to receive keyboard focus.
    Timer {
        id: focusKick

        interval: 50
        onTriggered: root.forceActiveFocus()
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

    Timer {
        id: wifiKick

        // execDetached has no completion callback: catch state changes from
        // disconnect/forget/radio-toggle a beat later
        interval: 1200
        onTriggered: root.wifiRefresh()
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.active && root.currentTab === 7

        onTriggered: root.wifiRefresh()
    }

    Process {
        id: geoProc

        command: ["curl", "-s", "--max-time", "8", "https://ipwho.is/"]

        stdout: StdioCollector {
            onStreamFinished: root.applyGeo(text)
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.weatherLoading = false;
                root.weatherFailed = true;
                weatherTimeout.stop();
            }
        }
    }

    Process {
        id: weatherProc

        stdout: StdioCollector {
            onStreamFinished: root.applyWeather(text)
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.weatherLoading = false;
                root.weatherFailed = true;
                weatherTimeout.stop();
            }
        }
    }

    Timer {
        id: weatherTimeout

        interval: 10000
        onTriggered: {
            root.weatherLoading = false;
            root.weatherFailed = true;
            geoProc.running = false;
            weatherProc.running = false;
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

    // Visible APs; --rescan yes forces a fresh scan and blocks until it is
    // done. Empty stdout (radio off, transient failure) keeps the old list.
    Process {
        id: wifiScanProc

        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SSID,SECURITY", "device", "wifi", "list", "--rescan", "yes"]

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.applyScan(text)
        }

        onExited: root.wifiScanning = false
    }

    Process {
        id: wifiMetaProc

        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: root.applyMeta(text)
        }
    }

    // command is set imperatively per connection attempt in wifiConnectTo().
    Process {
        id: wifiConnectProc

        onExited: exitCode => {
            root.wifiConnecting = "";
            if (exitCode !== 0) {
                root.wifiError = "Could not connect — check the password";
                return;
            }
            root.wifiPasswordFor = "";
            root.wifiRefresh();
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
                        icon: "coffee"
                        label: "Caffeine"
                        checked: Caffeine.enabled

                        onToggled: Caffeine.toggle()
                    }

                    QsChip {
                        visible: root.wifiAvailable
                        icon: root.wifiOn ? "wifi" : "wifi_off"
                        label: "Wi-Fi"
                        checked: root.wifiOn

                        // opens the networks view (tab 7) instead of toggling;
                        // write to the service — a currentTab write would break
                        // its QuickSettings.tab binding and kill IPC navigation
                        onToggled: QuickSettings.tab = 7
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

            Item {
                id: tabStrip

                readonly property int buttonWidth: 54
                readonly property int buttonSpacing: 4

                width: tabBar.implicitWidth
                height: tabBar.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter

                // One pill that glides between tabs, like a segmented control.
                Rectangle {
                    id: tabIndicator

                    width: tabStrip.buttonWidth
                    height: 36
                    radius: Theme.radiusMD
                    color: Theme.surfaceContainerHigh
                    x: Math.max(0, root.activeTabIndex) * (tabStrip.buttonWidth + tabStrip.buttonSpacing)
                    opacity: root.activeTabIndex >= 0 ? 1 : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.2
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                    }
                }

                Row {
                    id: tabBar

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: tabStrip.buttonSpacing

                    Repeater {
                        model: root.tabs

                        delegate: Rectangle {
                            id: tabBtn

                            required property var modelData

                            width: tabStrip.buttonWidth
                            height: 36
                            radius: Theme.radiusMD
                            color: "transparent"
                            scale: tabArea.pressed ? 0.97 : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration: tabArea.pressed ? 30 : 50
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: tabBtn.modelData.icon
                                color: root.currentTab === tabBtn.modelData.tab ? Theme.primary : Theme.surfaceVariantText
                                font.family: Theme.iconFont
                                font.pixelSize: 20

                                Behavior on color {
                                    ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                id: tabArea

                                anchors.fill: parent

                                onClicked: QuickSettings.tab = tabBtn.modelData.tab
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Ctrl + Page Up / Page Down to switch tabs"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 10
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

            NotifsTab {
                visible: root.currentTab === 5
            }

            PowerTab {
                visible: root.currentTab === 6
            }

            SettingsTab {
                visible: root.currentTab === 8
            }

            WifiTab {
                visible: root.currentTab === 7
            }

            SystemTab {}

            TrayTab {
                id: trayTab
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
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
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
            color: Theme.surfaceVariantText
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
        scale: chipArea.pressed ? 0.97 : 1

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Behavior on border.width {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            NumberAnimation {
                duration: chipArea.pressed ? 30 : 50
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: chipContent

            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                color: chip.checked ? Theme.containerText : Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 16
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.checked ? Theme.containerText : Theme.surfaceText
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
        color: {
            if (pill.accent)
                return pillArea.containsMouse ? Qt.lighter(Theme.primaryContainer, 1.12) : Theme.primaryContainer;
            return pillArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh;
        }
        scale: pillArea.pressed ? 0.97 : 1

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            NumberAnimation {
                duration: pillArea.pressed ? 30 : 50
                easing.type: Easing.OutCubic
            }
        }

        Text {
            id: pillLabel

            anchors.centerIn: parent
            text: pill.label
            color: pill.accent ? Theme.containerText : Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: pillArea

            anchors.fill: parent
            hoverEnabled: true

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
                    color: Theme.surfaceText
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
                        color: Theme.surfaceVariantText
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
                        color: Theme.surfaceVariantText
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
                        color: Theme.surfaceVariantText
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
                            color: cell.modelData.today ? Theme.primaryText
                                : cell.modelData.current ? Theme.surfaceText : Theme.surfaceVariantText
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
                color: root.timerRemainingMs > 0 || root.timerRunning ? Theme.surfaceText : Theme.surfaceVariantText
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
                color: Theme.surfaceText
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
                color: Theme.surfaceVariantText
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
                    color: Theme.surfaceVariantText
                    font.family: Theme.iconFont
                    font.pixelSize: 28
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No weather data — click to retry"
                    color: Theme.surfaceVariantText
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
                        color: Theme.surfaceText
                        font.family: Theme.fontFamily
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.weatherDesc
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "Feels " + root.weatherFeels + "°"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Wind " + root.weatherWind + " km/h"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Humidity " + root.weatherHumidity + "%"
                        color: Theme.surfaceVariantText
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
                            color: Theme.surfaceVariantText
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
                            color: Theme.surfaceText
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
            color: Theme.surfaceVariantText
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
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: (media.player?.trackArtist ?? "") !== ""
                text: media.player?.trackArtist ?? ""
                color: Theme.surfaceVariantText
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

    // Notification history: DND and clear in the header, then the same
    // pooled card list the toasts use. List caps at 55% of the screen and
    // scrolls inside it.
    component NotifsTab: Item {
        id: notifs

        width: parent.width
        height: notifsCol.implicitHeight
        visible: root.currentTab === 5

        readonly property int maxListHeight: Math.round(
            (Quickshell.screens.find(s => s.name === root.screenName)?.height ?? 900) * 0.55)

        Column {
            id: notifsCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 10

            RowLayout {
                width: parent.width
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    text: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    color: Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 17

                    MouseArea {
                        anchors.fill: parent

                        onClicked: Notifs.toggleDnd()
                    }
                }

                Text {
                    text: "delete_sweep"
                    color: Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 17

                    MouseArea {
                        anchors.fill: parent

                        onClicked: Notifs.clear()
                    }
                }
            }

            Flickable {
                id: notifsList

                width: parent.width
                height: Math.min(contentHeight, notifs.maxListHeight)
                contentHeight: notifsCards.implicitHeight
                clip: true

                Column {
                    id: notifsCards

                    width: notifsList.width
                    spacing: 8

                    Text {
                        visible: Notifs.list.length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "All caught up"
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    NotifColumn {
                        model: Notifs.list
                        // drop the card pool while this panel is closed
                        deferSync: !root.active
                        width: parent.width
                        spacing: 8
                    }
                }
            }
        }
    }

    // Wi-Fi networks view, opened by the Wi-Fi chip (tab 7, no strip icon):
    // visible APs first, then saved profiles. The password input lives here —
    // the bar grabs the keyboard only while it is visible.
    component WifiTab: Item {
        id: wifiView

        width: parent.width
        height: wifiCol.implicitHeight
        visible: root.currentTab === 7

        readonly property int maxListHeight: Math.round(
            (Quickshell.screens.find(s => s.name === root.screenName)?.height ?? 900) * 0.45)

        // layer surfaces take a beat to receive keyboard focus
        Timer {
            id: pwFocusKick

            interval: 50
            onTriggered: pwInput.forceActiveFocus()
        }

        Column {
            id: wifiCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 10

            RowLayout {
                width: parent.width
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    text: root.wifiOn ? "wifi" : "wifi_off"
                    color: Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 17

                    MouseArea {
                        anchors.fill: parent

                        onClicked: root.setWifi(!root.wifiOn)
                    }
                }

                Text {
                    text: "refresh"
                    color: Theme.primary
                    opacity: root.wifiScanning ? 0.4 : 1
                    font.family: Theme.iconFont
                    font.pixelSize: 17

                    MouseArea {
                        anchors.fill: parent

                        onClicked: root.wifiRefresh()
                    }
                }
            }

            Text {
                visible: root.wifiError !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.wifiError
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                visible: root.wifiConnecting !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Connecting to " + root.wifiConnecting + "\u2026"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Rectangle {
                visible: root.wifiPasswordFor !== ""
                width: parent.width
                height: 34
                radius: Theme.radiusMD
                color: Theme.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 4
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "lock"
                        color: Theme.surfaceVariantText
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pwInput.text === ""
                            text: "Password for " + root.wifiPasswordFor
                            color: Theme.surfaceVariantText
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }

                        TextInput {
                            id: pwInput

                            anchors.fill: parent
                            color: Theme.surfaceText
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            echoMode: TextInput.Password
                            selectByMouse: true
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.containerText
                            focus: root.wifiPasswordFor !== ""

                            onAccepted: root.wifiConnectTo(root.wifiPasswordFor, text)
                            Keys.onEscapePressed: root.wifiPasswordFor = ""

                            onVisibleChanged: {
                                if (visible) {
                                    text = "";
                                    pwFocusKick.restart();
                                }
                            }
                        }
                    }

                    PillButton {
                        Layout.alignment: Qt.AlignVCenter
                        accent: true
                        label: "Connect"

                        onClicked: root.wifiConnectTo(root.wifiPasswordFor, pwInput.text)
                    }
                }
            }

            Flickable {
                id: wifiList

                width: parent.width
                height: Math.min(contentHeight, wifiView.maxListHeight)
                contentHeight: wifiCards.implicitHeight
                clip: true

                Column {
                    id: wifiCards

                    width: wifiList.width
                    spacing: 6

                    Text {
                        visible: !root.wifiOn
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Wi-Fi is off"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        visible: root.wifiOn && root.wifiScanning && root.wifiNetworks.length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Scanning\u2026"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        visible: root.wifiOn && !root.wifiScanning && root.wifiNetworks.length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No networks found"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: root.wifiNetworks

                        delegate: WifiRow {}
                    }

                    Text {
                        visible: root.wifiSaved.length > 0
                        text: "Saved"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: root.wifiSaved

                        delegate: SavedRow {}
                    }
                }
            }
        }
    }

    // One scanned network: signal icon, ssid, lock, check when connected.
    // Deliberately animation-free — the Repeater recreates rows on every scan;
    // the password input lives above the list, so it survives rebuilds.
    component WifiRow: Rectangle {
        id: netRow

        required property var modelData

        width: parent.width
        height: 34
        radius: Theme.radiusMD
        color: netArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
        opacity: root.wifiConnecting === netRow.modelData.ssid ? 0.5 : 1

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: netArea

            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.wifiClicked(netRow.modelData)
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiSignalIcon(netRow.modelData.signal)
                color: netRow.modelData.inUse ? Theme.primary : Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: 17
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: netRow.width - 150
                text: netRow.modelData.ssid
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: netRow.modelData.secured
                text: "lock"
                color: Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: 13
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: netRow.modelData.inUse && root.wifiConnecting === ""
                text: "check"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 17
            }

            PillButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: netRow.modelData.inUse
                label: "Disconnect"

                onClicked: root.wifiDisconnect()
            }
        }
    }

    // One saved profile: name plus a delete (forget) button. The row itself
    // only highlights — forgetting is deliberate, via the button.
    component SavedRow: Rectangle {
        id: savedRow

        required property var modelData

        width: parent.width
        height: 30
        radius: Theme.radiusMD
        color: savedArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: savedArea

            anchors.fill: parent
            hoverEnabled: true
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "bookmark"
                color: Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: savedRow.width - 130
                text: savedRow.modelData.name
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "delete"
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: 16

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onClicked: root.wifiForget(savedRow.modelData.name)
            }
        }
    }

    // Theme settings: color scheme (Matugen/Gruvbox), bar style, and per-app
    // color targets rewritten by SystemTheme from the active palette.
    component SettingsTab: Item {
        id: settingsTab

        width: parent.width
        height: settingsCol.implicitHeight

        Column {
            id: settingsCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 10

            Text {
                text: "Bar style"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Row {
                spacing: 6

                QsChip {
                    icon: "vertical_align_top"
                    label: "Notch"
                    checked: !BarState.island

                    onToggled: BarState.setStyle("notch")
                }

                QsChip {
                    icon: "crop_free"
                    label: "Island"
                    checked: BarState.island

                    onToggled: BarState.setStyle("island")
                }
            }

            Text {
                width: parent.width
                text: "Notch sits flush with the top edge; Island floats with a gap."
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.plateBorder
            }

            Text {
                text: "Color scheme"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Row {
                spacing: 6

                QsChip {
                    icon: "auto_awesome"
                    label: "Matugen"
                    checked: SystemTheme.colorScheme !== "gruvbox"

                    onToggled: SystemTheme.setColorScheme("matugen")
                }

                QsChip {
                    icon: "palette"
                    label: "Gruvbox"
                    checked: SystemTheme.colorScheme === "gruvbox"

                    onToggled: SystemTheme.setColorScheme("gruvbox")
                }
            }

            Text {
                width: parent.width
                text: "Matugen follows the wallpaper palette. Gruvbox uses a fixed palette. Both apply to enabled app configs below."
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.plateBorder
            }

            RowLayout {
                width: parent.width
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "App colors"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                PillButton {
                    accent: true
                    label: "Apply now"

                    onClicked: SystemTheme.applyAll()
                }
            }

            Text {
                width: parent.width
                text: "Selected applications follow the active color scheme. Off keeps the last colors."
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: SystemTheme.groups

                delegate: Column {
                    id: appGroup

                    required property var modelData

                    width: settingsCol.width
                    spacing: 6

                    Text {
                        text: appGroup.modelData.label
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: appGroup.modelData.apps

                            delegate: QsChip {
                                required property var modelData

                                icon: modelData.icon
                                label: modelData.label
                                checked: SystemTheme.enabled(modelData.id)

                                onToggled: SystemTheme.setEnabled(modelData.id, !checked)
                            }
                        }
                    }
                }
            }
        }
    }

    component PowerTab: Item {
        width: parent.width
        height: powerCol.implicitHeight
        visible: root.currentTab === 6

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
        scale: powerArea.pressed ? 0.97 : 1

        Behavior on scale {
            NumberAnimation {
                duration: powerArea.pressed ? 30 : 50
                easing.type: Easing.OutCubic
            }
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
                color: powerBtn.danger ? Theme.error : Theme.surfaceText
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

    // CPU/GPU load and temperature, RAM. /proc and sysfs are read through
    // FileView.reload() so each tick costs no process spawn; the timer only
    // runs while the panel shows this tab.
    component SystemTab: Item {
        id: sysTab

        width: parent.width
        height: sysCol.implicitHeight
        visible: root.currentTab === 9

        readonly property bool monitoring: root.active && sysTab.visible

        property int cpuPct: 0
        property string cpuTemp: "—"
        property int gpuPct: 0
        property string gpuTemp: "—"
        property bool hasGpu: false
        property int ramPct: 0
        property real ramUsed: 0
        property real ramTotal: 0
        property real prevTotal: 0
        property real prevIdle: 0
        property bool statReady: false
        property string cpuTempPath: ""
        property string gpuBusyPath: ""
        property string gpuTempPath: ""

        function tempText(raw: string): string {
            const t = parseInt(raw.trim());
            return isNaN(t) ? "—" : Math.round(t / 1000) + "°C";
        }

        function refresh(): void {
            statFile.reload();
            memFile.reload();
            if (sysTab.cpuTempPath !== "")
                cpuTempFile.reload();
            if (sysTab.gpuBusyPath !== "")
                gpuBusyFile.reload();
            if (sysTab.gpuTempPath !== "")
                gpuTempFile.reload();
        }

        onMonitoringChanged: {
            if (sysTab.monitoring)
                sysTab.refresh();
        }

        Component.onCompleted: hwProbe.running = true

        Timer {
            interval: 1000
            repeat: true
            running: sysTab.monitoring

            onTriggered: sysTab.refresh()
        }

        // First line of /proc/stat: cpu user nice system idle iowait irq
        // softirq steal ... — usage is the non-idle share of the delta.
        FileView {
            id: statFile

            path: "/proc/stat"
            preload: false
            blockAllReads: true
            watchChanges: false
            printErrors: false

            onTextChanged: {
                const parts = text().slice(0, text().indexOf("\n")).trim().split(/\s+/).map(Number);
                if (parts.length < 6)
                    return;
                const idle = parts[4] + (parts[5] || 0);
                const total = parts.slice(1, 9).reduce((a, b) => a + b, 0);
                if (!sysTab.statReady) {
                    sysTab.prevTotal = total;
                    sysTab.prevIdle = idle;
                    sysTab.statReady = true;
                    return;
                }
                const dt = total - sysTab.prevTotal;
                const di = idle - sysTab.prevIdle;
                if (dt > 0)
                    sysTab.cpuPct = Math.round(100 * (dt - di) / dt);
                sysTab.prevTotal = total;
                sysTab.prevIdle = idle;
            }
        }

        FileView {
            id: memFile

            path: "/proc/meminfo"
            preload: false
            blockAllReads: true
            watchChanges: false
            printErrors: false

            onTextChanged: {
                const data = text();
                const total = parseInt(data.slice(data.indexOf("MemTotal:") + 9));
                const available = parseInt(data.slice(data.indexOf("MemAvailable:") + 13));
                // A missing key parses to NaN; reject that too.
                if (!(total > 0) || !(available >= 0))
                    return;
                sysTab.ramTotal = total / 1048576;
                sysTab.ramUsed = (total - available) / 1048576;
                sysTab.ramPct = Math.round(100 * sysTab.ramUsed / sysTab.ramTotal);
            }
        }

        FileView {
            id: cpuTempFile

            path: sysTab.cpuTempPath
            preload: false
            blockAllReads: true
            watchChanges: false
            printErrors: false

            onTextChanged: sysTab.cpuTemp = sysTab.tempText(text())
        }

        FileView {
            id: gpuBusyFile

            path: sysTab.gpuBusyPath
            preload: false
            blockAllReads: true
            watchChanges: false
            printErrors: false

            onTextChanged: {
                const v = parseInt(text().trim());
                if (!isNaN(v))
                    sysTab.gpuPct = v;
            }
        }

        FileView {
            id: gpuTempFile

            path: sysTab.gpuTempPath
            preload: false
            blockAllReads: true
            watchChanges: false
            printErrors: false

            onTextChanged: sysTab.gpuTemp = sysTab.tempText(text())
        }

        // The hwmon indices are not stable across boots, so resolve the CPU
        // and amdgpu paths once. k10temp (AMD) and coretemp (Intel) expose
        // the package temperature on temp1_input.
        Process {
            id: hwProbe

            command: [
                "sh", "-c",
                "cpu=$(for h in /sys/class/hwmon/hwmon*; do " +
                "case \"$(cat \"$h/name\" 2>/dev/null)\" in k10temp|coretemp|zenpower) " +
                "echo \"$h/temp1_input\"; break;; esac; done); " +
                "gpu=$(for f in /sys/class/drm/card*/device/gpu_busy_percent; do " +
                "[ -r \"$f\" ] && { echo \"$f\"; break; }; done); " +
                "gt=$(for h in /sys/class/hwmon/hwmon*; do " +
                "[ \"$(cat \"$h/name\" 2>/dev/null)\" = amdgpu ] && " +
                "{ echo \"$h/temp1_input\"; break; }; done); " +
                "echo \"$cpu|$gpu|$gt\""
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    const parts = text.trim().split("|");
                    sysTab.cpuTempPath = parts[0] ?? "";
                    sysTab.gpuBusyPath = parts[1] ?? "";
                    sysTab.gpuTempPath = parts[2] ?? "";
                    sysTab.hasGpu = sysTab.gpuBusyPath !== "";
                    sysTab.refresh();
                }
            }
        }

        Column {
            id: sysCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 14

            Meter {
                label: "CPU"
                value: sysTab.cpuPct + "% · " + sysTab.cpuTemp
                percent: sysTab.cpuPct
                fill: Theme.primary
            }

            Meter {
                visible: sysTab.hasGpu
                label: "GPU"
                value: sysTab.gpuPct + "% · " + sysTab.gpuTemp
                percent: sysTab.gpuPct
                fill: Theme.tertiary
            }

            Meter {
                label: "RAM"
                value: sysTab.ramPct + "% · " + sysTab.ramUsed.toFixed(1)
                    + " / " + sysTab.ramTotal.toFixed(1) + " GiB"
                percent: sysTab.ramPct
                fill: Theme.secondary
            }
        }
    }

    // StatusNotifierItems, as a list; an item with a D-Bus menu swaps the
    // list for that menu, rendered in place (native menus cannot attach to
    // a layer-shell surface). Submenus push deeper; back pops one level.
    component TrayTab: Item {
        id: trayView

        width: parent.width
        height: trayCol.implicitHeight
        visible: root.currentTab === 10

        readonly property var items: SystemTray.items.values
        readonly property int maxListHeight: Math.round(
            (Quickshell.screens.find(s => s.name === root.screenName)?.height ?? 900) * 0.45)
        readonly property var activeMenu: trayView.menuStack.length > 0
            ? trayView.menuStack[trayView.menuStack.length - 1] : null
        readonly property var menuEntries: trayView.activeMenu !== null
            ? menuOpener.children.values : []

        property var activeItem: null
        property var menuStack: []

        function openItem(item: var): void {
            trayView.activeItem = item;
            trayView.menuStack = item !== null && item.hasMenu ? [item.menu] : [];
        }

        function pushMenu(entry: var): void {
            trayView.menuStack = [...trayView.menuStack, entry];
        }

        function back(): void {
            if (trayView.menuStack.length > 1)
                trayView.menuStack = trayView.menuStack.slice(0, -1);
            else
                trayView.openItem(null);
        }

        function reset(): void {
            trayView.openItem(null);
        }

        // An app can quit while its menu is open; drop the stale item.
        onItemsChanged: {
            if (trayView.activeItem !== null && !trayView.items.includes(trayView.activeItem))
                trayView.openItem(null);
        }

        QsMenuOpener {
            id: menuOpener

            menu: trayView.activeMenu
        }

        Column {
            id: trayCol

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 10

            RowLayout {
                width: parent.width
                spacing: 6

                Item {
                    visible: trayView.activeItem !== null
                    implicitWidth: 28
                    implicitHeight: 28

                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        color: Theme.primary
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: trayView.back()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: trayView.activeItem !== null
                        ? (trayView.activeItem.title !== "" ? trayView.activeItem.title : trayView.activeItem.id)
                        : "Tray"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            Flickable {
                visible: trayView.activeItem === null
                width: parent.width
                height: Math.min(contentHeight, trayView.maxListHeight)
                contentHeight: trayList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: trayList

                    width: parent.width
                    spacing: 2

                    Text {
                        visible: trayView.items.length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No tray apps"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: trayView.items

                        delegate: TrayRow {
                            required property var modelData

                            width: trayList.width
                            item: modelData

                            onClicked: {
                                if (modelData.hasMenu) {
                                    trayView.openItem(modelData);
                                } else {
                                    modelData.activate();
                                    QuickSettings.close();
                                }
                            }
                        }
                    }
                }
            }

            Flickable {
                visible: trayView.activeItem !== null
                width: parent.width
                height: Math.min(contentHeight, trayView.maxListHeight)
                contentHeight: menuList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: menuList

                    width: parent.width
                    spacing: 1

                    Text {
                        visible: trayView.menuEntries.length === 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No menu"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: trayView.menuEntries

                        delegate: TrayMenuRow {
                            required property var modelData

                            width: menuList.width
                            entry: modelData

                            onClicked: {
                                if (modelData.hasChildren) {
                                    trayView.pushMenu(modelData);
                                } else {
                                    modelData.triggered();
                                    trayView.reset();
                                    QuickSettings.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // One metric row: label and value over a thin proportional bar.
    component Meter: Column {
        id: meter

        required property string label
        required property string value
        required property int percent
        property color fill: Theme.primary

        width: parent ? parent.width : 0
        spacing: 6

        RowLayout {
            width: parent.width
            spacing: 8

            Text {
                text: meter.label
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: meter.value
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.14)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.percent / 100))
                height: parent.height
                radius: parent.radius
                color: meter.fill

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    component TrayRow: Rectangle {
        id: trayRow

        required property var item
        signal clicked()

        width: parent ? parent.width : 0
        height: 38
        radius: Theme.radiusMD
        color: trayArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        IconImage {
            id: trayIcon

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 20
            source: trayRow.item.icon
        }

        Text {
            anchors.left: trayIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: trayRow.item.title !== "" ? trayRow.item.title : trayRow.item.id
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        MouseArea {
            id: trayArea

            anchors.fill: parent
            hoverEnabled: true

            onClicked: trayRow.clicked()
        }
    }

    // One D-Bus menu entry: separator, check mark, icon, text, submenu arrow.
    component TrayMenuRow: Rectangle {
        id: menuRow

        required property var entry
        signal clicked()

        readonly property bool actionable: !menuRow.entry.isSeparator && menuRow.entry.enabled

        width: parent ? parent.width : 0
        height: menuRow.entry.isSeparator ? 9 : 34
        radius: Theme.radiusMD
        color: menuArea.containsMouse && menuRow.actionable ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        Rectangle {
            visible: menuRow.entry.isSeparator
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 8
                rightMargin: 8
            }
            height: 1
            color: Theme.outline
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            visible: !menuRow.entry.isSeparator && menuRow.entry.checkState === Qt.Checked
            text: "check"
            color: Theme.primary
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        IconImage {
            id: entryIcon

            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 14
            visible: !menuRow.entry.isSeparator && menuRow.entry.icon !== ""
            source: menuRow.entry.icon
        }

        Text {
            anchors.left: entryIcon.visible ? entryIcon.right : parent.left
            anchors.leftMargin: entryIcon.visible ? 6 : 28
            anchors.right: childIcon.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: !menuRow.entry.isSeparator
            text: menuRow.entry.text
            color: Theme.surfaceText
            opacity: menuRow.entry.enabled ? 1 : 0.5
            font.family: Theme.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            id: childIcon

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: !menuRow.entry.isSeparator && menuRow.entry.hasChildren
            text: "chevron_right"
            color: Theme.surfaceVariantText
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        MouseArea {
            id: menuArea

            anchors.fill: parent
            enabled: menuRow.actionable
            hoverEnabled: true

            onClicked: menuRow.clicked()
        }
    }
}
