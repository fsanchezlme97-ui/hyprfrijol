pragma Singleton
// Tiempo con Open-Meteo (sin clave). Ubicación: ajustes weatherLat / weatherLon / weatherCity; si no hay,
// se pregunta una vez a https://ipapi.co/json y (o https://ipinfo.io/json si limita) y se guarda en ~/.cache/hyprfrijol/weather.json.
// La última previsión también se guarda para verla sin conexión. Se refresca cada 30 min mientras se usa.
//   Weather.users++ / --, temp, code, isDay, city, desc, icon, days [{ d: "vie", max, min, code }], err
//   Detalle (ventana del clima de la barra): feels, humidity, wind (km/h), today { max, min, pop, sunrise, sunset },
//   hours [{ h: "14", temp, code, day, pop }] (las próximas 24 h), updatedText ("hace 5 min")
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    property int users: 0
    property real temp: NaN
    property int code: -1
    property bool isDay: true
    property string city: Settings.get("weatherCity", "")
    property var days: []
    property string err: ""
    property real fetched: 0
    property var loc: null               // { lat, lon, city }
    property real feels: NaN
    property real humidity: NaN
    property real wind: NaN
    property var today: null
    property var hours: []
    readonly property bool ready: !isNaN(temp)
    readonly property string desc: describe(code)
    readonly property string icon: iconFor(code, isDay)

    // "" (el valor por defecto) es «sin ciudad fija»: Number("") sería 0 → el golfo de Guinea
    readonly property real setLat: num(Settings.get("weatherLat", ""))
    readonly property real setLon: num(Settings.get("weatherLon", ""))
    function num(v): real { return v === "" || v === null || v === undefined ? NaN : Number(v); }
    // Ubicación conocida (ciudad fija o la última por IP). La usa también Sun (amanecer/atardecer).
    readonly property var where: !isNaN(setLat) && !isNaN(setLon) ? { lat: setLat, lon: setLon, city: Settings.get("weatherCity", "") } : loc
    // Averiguar la ubicación sin pedir el tiempo (Sun la necesita aunque no haya widget del clima)
    function locate(): void {
        if (where || geo.running || Settings.get("weatherIpLocation", true) === false) return;
        geo.running = true;
    }

    function describe(c: int): string {
        if (c < 0) return "";
        if (c === 0) return "despejado";
        if (c <= 2) return "poco nuboso";
        if (c === 3) return "nublado";
        if (c <= 48) return "niebla";
        if (c <= 57) return "llovizna";
        if (c <= 67) return "lluvia";
        if (c <= 77) return "nieve";
        if (c <= 82) return "chubascos";
        if (c <= 86) return "chubascos de nieve";
        return "tormenta";
    }
    function iconFor(c: int, day: bool): string {
        if (c < 0) return "cloud";
        if (c <= 1) return day ? "sun" : "moon";
        if (c <= 48) return "cloud";
        if (c <= 82) return "drop";
        if (c <= 86) return "cloud";
        return "alert";
    }

    function refresh(): void {
        if (!isNaN(setLat) && !isNaN(setLon)) {
            loc = { lat: setLat, lon: setLon, city: Settings.get("weatherCity", ""), fixed: true };
            fetchWeather();
            return;
        }
        if (loc && loc.fixed) loc = null;          // se quitó la ciudad fija: se vuelve a la ubicación por IP
        if (loc) fetchWeather();
        else if (Settings.get("weatherIpLocation", true) !== false) geo.running = true;   // Ajustes › Privacidad
        else err = "Pon tu ciudad en Ajustes › Escritorio";
    }
    // Ciudad escrita en Ajustes › Escritorio: se busca en Open-Meteo y se guardan sus coordenadas (vacía = por IP)
    property string cityErr: ""
    function setCity(name: string): void {
        name = String(name ?? "").trim();
        cityErr = "";
        if (name === "") { Settings.setMany({ weatherCity: "", weatherLat: "", weatherLon: "" }); return; }
        if (name === Settings.get("weatherCity", "") && !isNaN(setLat)) return;
        cityProc.name = name;
        cityProc.command = ["curl", "-fsS", "--max-time", "10", "-G", "https://geocoding-api.open-meteo.com/v1/search",
                            "--data-urlencode", "name=" + name, "-d", "count=1", "-d", "language=es", "-d", "format=json"];
        cityProc.running = true;
    }
    Process {
        id: cityProc
        property string name: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = (JSON.parse(text).results ?? [])[0];
                    if (!r) { root.cityErr = "No encuentro «" + cityProc.name + "»"; return; }
                    Settings.setMany({ weatherCity: r.name, weatherLat: r.latitude, weatherLon: r.longitude });
                } catch (e) { root.cityErr = "No se pudo buscar la ciudad (sin conexión)"; }
            }
        }
    }
    function fetchWeather(): void {
        const u = "https://api.open-meteo.com/v1/forecast?latitude=" + loc.lat + "&longitude=" + loc.lon
            + "&current=temperature_2m,weather_code,is_day,apparent_temperature,relative_humidity_2m,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code,is_day,precipitation_probability"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&timezone=auto&forecast_days=4";
        wx.command = ["curl", "-fsS", "--max-time", "12", u];
        wx.running = true;
    }
    property var lastData: null
    function applyData(d): void {
        lastData = d;
        temp = d.current?.temperature_2m ?? NaN;
        code = d.current?.weather_code ?? -1;
        isDay = (d.current?.is_day ?? 1) === 1;
        const L = Qt.locale("es_ES"), dd = d.daily ?? {};
        days = (dd.time ?? []).slice(1, 4).map((t, i) => ({
            d: L.toString(new Date(t + "T12:00:00"), "ddd").replace(".", ""),
            max: Math.round(dd.temperature_2m_max[i + 1]),
            min: Math.round(dd.temperature_2m_min[i + 1]),
            code: dd.weather_code[i + 1]
        }));
        city = loc?.city || Settings.get("weatherCity", "") || city;
        feels = d.current?.apparent_temperature ?? NaN;
        humidity = d.current?.relative_humidity_2m ?? NaN;
        wind = d.current?.wind_speed_10m ?? NaN;
        const hm = s => String(s ?? "").slice(11, 16);
        today = (dd.time ?? []).length ? {
            max: Math.round(dd.temperature_2m_max[0]), min: Math.round(dd.temperature_2m_min[0]),
            pop: dd.precipitation_probability_max?.[0] ?? -1, sunrise: hm(dd.sunrise?.[0]), sunset: hm(dd.sunset?.[0]), code: dd.weather_code[0]
        } : null;
        // Próximas 24 h desde la hora actual (las horas vienen en la zona del lugar, igual que current.time)
        const hh = d.hourly ?? {}, now = String(d.current?.time ?? "").slice(0, 13);
        let i0 = (hh.time ?? []).findIndex(t => String(t).slice(0, 13) >= now);
        if (i0 < 0) i0 = 0;
        hours = (hh.time ?? []).slice(i0, i0 + 24).map((t, i) => ({
            h: String(t).slice(11, 13), temp: Math.round(hh.temperature_2m[i0 + i]), code: hh.weather_code[i0 + i],
            day: (hh.is_day?.[i0 + i] ?? 1) === 1, pop: hh.precipitation_probability?.[i0 + i] ?? -1
        }));
    }
    readonly property string updatedText: {
        if (!fetched) return "";
        const m = Math.round((Time.now - fetched) / 60000);
        return m < 1 ? "ahora mismo" : m < 60 ? "hace " + m + " min" : "hace " + Math.round(m / 60) + " h";
    }

    // Esperar a Settings: si no, la primera vuelta no ve la ciudad fija ni weatherIpLocation = false y pregunta por IP
    Timer { running: root.users > 0 && Settings.loaded; repeat: true; interval: 30 * 60 * 1000; triggeredOnStart: true; onTriggered: root.refresh() }
    onSetLatChanged: if (users > 0) refresh()
    onSetLonChanged: if (users > 0) refresh()

    // Caché (ubicación + última previsión)
    FileView {
        id: cache
        path: Paths.cache + "/weather.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (!root.loc && c.loc) root.loc = c.loc;
                if (!root.ready && c.data) root.applyData(c.data);
            } catch (e) {}
        }
    }
    Process {
        id: geo
        // ipapi.co y, si limita las peticiones (429), ipinfo.io
        command: ["sh", "-c", 'curl -fsS --max-time 8 https://ipapi.co/json || curl -fsS --max-time 8 https://ipinfo.io/json']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const g = JSON.parse(text);
                    const ll = g.latitude !== undefined ? [g.latitude, g.longitude] : String(g.loc ?? "").split(",").map(Number);
                    if (ll.length !== 2 || isNaN(ll[0]) || isNaN(ll[1])) throw "sin ubicación";
                    if (!isNaN(root.setLat) && !isNaN(root.setLon)) return;   // entretanto se puso una ciudad fija
                    root.loc = { lat: ll[0], lon: ll[1], city: g.city ?? "" };
                    if (root.users > 0) root.fetchWeather();
                    else { Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1"', "sh", Paths.cache]); cache.setText(JSON.stringify({ loc: root.loc, data: root.lastData })); }
                } catch (e) { root.err = "No se pudo saber tu ubicación · ponla en Ajustes"; }
            }
        }
    }
    Process {
        id: wx
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.applyData(d);
                    root.err = "";
                    root.fetched = Date.now();
                    Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1"', "sh", Paths.cache]);
                    cache.setText(JSON.stringify({ loc: root.loc, data: d }));
                } catch (e) { if (!root.ready) root.err = "Sin conexión con Open-Meteo"; }
            }
        }
        onExited: code => { if (code !== 0) { if (!root.ready) root.err = "Sin conexión con Open-Meteo"; retry.restart(); } }
    }
    // Sin red al arrancar (o un fallo suelto): se reintenta al minuto en vez de esperar a la siguiente media hora
    Timer { id: retry; interval: 60000; onTriggered: if (root.users > 0) root.refresh() }
}
