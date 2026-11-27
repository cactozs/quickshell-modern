pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    title: "Погода"
    icon: root.weatherIcon
    cardWidth: 240

    property bool loading: false
    property bool failed: false
    property string temp: "—"
    property string feels: ""
    property string desc: "Загрузка..."
    property string weatherIcon: "partly_cloudy_day"
    property var coords: null

    function weatherCodeInfo(code: var): var {
        const c = parseInt(code);
        if (c === 0) return { icon: "clear_day", desc: "Ясно" };
        if (c === 1) return { icon: "partly_cloudy_day", desc: "Преимущественно ясно" };
        if (c === 2) return { icon: "partly_cloudy_day", desc: "Переменная облачность" };
        if (c === 3) return { icon: "cloud", desc: "Пасмурно" };
        if (c === 45 || c === 48) return { icon: "foggy", desc: "Туман" };
        if (c >= 51 && c <= 67) return { icon: "rainy", desc: "Дождь" };
        if (c >= 71 && c <= 77) return { icon: "weather_snowy", desc: "Снег" };
        if (c >= 80 && c <= 82) return { icon: "rainy", desc: "Ливни" };
        if (c >= 85 && c <= 86) return { icon: "weather_snowy", desc: "Снегопад" };
        if (c >= 95) return { icon: "thunderstorm", desc: "Гроза" };
        return { icon: "partly_cloudy_day", desc: "Погода" };
    }

    function fetchWeather(): void {
        if (geoProc.running || weatherProc.running) return;
        root.loading = true;
        root.failed = false;
        if (root.coords !== null) startWeatherFetch();
        else geoProc.running = true;
    }

    function startWeatherFetch(): void {
        const c = root.coords;
        weatherProc.command = ["curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + c.lat
            + "&longitude=" + c.lon
            + "&current=temperature_2m,apparent_temperature,weather_code"
            + "&timezone=auto&forecast_days=1"];
        weatherProc.running = true;
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }

    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "5", "http://ip-api.com/json/?fields=status,lat,lon"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data?.status === "success") {
                        root.coords = { lat: data.lat, lon: data.lon };
                        root.startWeatherFetch();
                        return;
                    }
                } catch (e) {}
                root.loading = false;
                root.failed = true;
                root.desc = "Не удалось определить место";
            }
        }
        onExited: code => { if (code !== 0) { root.loading = false; root.failed = true; root.desc = "Нет сети"; } }
    }

    Process {
        id: weatherProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const cur = JSON.parse(text)?.current;
                    const info = root.weatherCodeInfo(cur.weather_code);
                    const temp = Number(cur?.temperature_2m);
                    const feels = Number(cur?.apparent_temperature);
                    if (!Number.isFinite(temp))
                        throw new Error("bad weather payload");
                    root.weatherIcon = info.icon;
                    root.desc = info.desc;
                    root.temp = Math.round(temp) + "°";
                    root.feels = "Ощущается " + Math.round(Number.isFinite(feels) ? feels : temp) + "°";
                    root.failed = false;
                    return;
                } catch (e) {}
                root.failed = true;
                root.desc = "Ошибка погоды";
            }
        }
        onExited: code => { if (code !== 0) { root.loading = false; root.failed = true; root.desc = "Ошибка погоды"; } }
    }

    Text {
        Layout.fillWidth: true
        text: root.temp
        color: Qt.lighter(Theme.primary, 1.2)
        font.family: Theme.fontFamily
        font.pixelSize: 34
        font.weight: Font.DemiBold
    }

    Text {
        Layout.fillWidth: true
        text: root.desc
        color: Theme.surfaceText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        visible: root.feels !== ""
        text: root.feels
        color: Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
