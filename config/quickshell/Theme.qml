pragma Singleton
// Tema del shell. Lo calcula scripts/hf-apply (paleta + modo de color + estilo, con los mismos tokens que el diseño)
// y lo deja en ~/.local/state/hyprfrijol/theme.json; aquí solo se lee, y se actualiza en vivo.
//
//  Colores (c.* del diseño):  bg s1 s3 s4 · p pText · pc pcText · sc scText · ter · t tv · o ov
//  Estilo  (S.* del diseño → Theme.st):  glass glassPanel glassPopup fill2 · border borderWidth highlight glow
//                             shadow shadowBig shBlur shY · card cardBorder · barRadius panelRadius winRadius · blur
//           estilos: flat (Material) · skysoul (Material de cristal: transparente y desenfocado) · chroma (Nothing)
//                    · tonal (interno). La geometría (radios) es la misma en todos: Ajustes › Apariencia › Redondeo
//  Movimiento: dur durIn durOut · ease easeIn easeOut (theme.json motion)
//  Tipografía: font, size(px) — tamaño base 12.5 como en el diseño
//  Nota: en QML los nombres "on" + mayúscula son manejadores, por eso pText (=onP), pcText (=onPc)…
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: ({})
    readonly property var c: data.c ?? fallback.c
    readonly property var st: data.S ?? fallback.st

    readonly property bool light: data.light ?? false
    // Nombres de antes (theme.json antiguo): aurora/liquid → skysoul, mica → chroma, suave/soft → flat
    readonly property string estilo: ({ aurora: "skysoul", liquid: "skysoul", mica: "chroma", suave: "flat", soft: "flat" })[st.estilo] ?? st.estilo
    readonly property string paletteName: data.paletteName ?? "Grafito"
    readonly property bool reduceMotion: data.reduceMotion ?? false
    readonly property bool highContrast: data.highContrast ?? false     // Ajustes › Accesibilidad (hf-apply ya ajusta c y S)

    // Colores
    readonly property color bg: c.bg
    readonly property color s1: c.s1
    readonly property color s3: c.s3
    readonly property color s4: c.s4
    readonly property color p: c.p
    readonly property color pText: c.onP
    readonly property color pc: c.pc
    readonly property color pcText: c.onPc
    readonly property color sc: c.sc
    readonly property color scText: c.onSc
    readonly property color ter: c.ter
    readonly property color t: c.t
    readonly property color tv: c.tv
    readonly property color o: c.o
    readonly property color ov: c.ov
    readonly property color danger: chroma ? "#D71921" : light ? "#B3261E" : "#F2B8B5"

    // Estilo
    readonly property color glass: st.bg
    readonly property color glassPanel: st.bgPanel
    readonly property color glassPopup: st.bgPopup
    readonly property color fill2: st.bg2
    readonly property color border: st.border
    readonly property int borderWidth: st.borderWidth
    readonly property color highlight: st.highlight
    readonly property color glow: st.glow
    readonly property color shadow: st.shadow
    readonly property color shadowBig: st.shadowBig
    readonly property color win: st.win
    // Ventanas grandes (Ajustes, Centro de aplicaciones): en SkySoul más opaco que los paneles, para que no se transparente
    // lo de detrás; en Material/tonal, sólido. (hf-apply: S.winSolid)
    readonly property color winSolid: st.winSolid ?? (glassy ? Qt.alpha(st.win, 0.94) : c.s1)
    readonly property int barRadius: st.barRad
    readonly property int panelRadius: st.panelRad
    readonly property int winRadius: st.winRad
    readonly property bool blur: st.blur
    // Controles (botones, campos, segmentos): radio, o píldora completa si el estilo lo pide (st.pill)
    readonly property int ctlRadius: st.ctlRad ?? 7
    readonly property bool pill: st.pill ?? false
    function ctl(h: real): real { return pill ? h / 2 : Math.min(ctlRadius, h / 2); }
    // Radios fijos de los módulos (los del diseño) escalados según el estilo y el redondeo elegido
    readonly property real roundK: st.roundK ?? 1
    function r(n: real): real { return Math.round(n * roundK); }
    // Cristal de SkySoul: filo interior de luz (arriba → abajo), filo exterior, esmerilado y resplandor
    readonly property color rimTop: st.rimTop ?? "transparent"
    readonly property color rimBottom: st.rimBottom ?? "transparent"
    readonly property color sheen: st.sheen ?? "transparent"
    readonly property color tint: st.tint ?? "transparent"
    readonly property color tint2: st.tint2 ?? "transparent"
    readonly property color tint3: st.tint3 ?? "transparent"
    readonly property color edge: st.edge ?? "transparent"           // SkySoul: filo exterior oscuro casi invisible
    readonly property color accent2: st.accent2 ?? p                 // Chroma: el rojo
    // glassy: SkySoul (Material de cristal). Chroma (Nothing) es sólido, con su propia paleta y tipografía.
    readonly property bool glassy: estilo === "skysoul"
    readonly property bool chroma: estilo === "chroma"
    // Marca de selección en segmentos con el contenedor primario (Material)
    readonly property bool tonalSel: estilo === "flat"
    // Marca deslizante de los segmentos (y su texto): Material el contenedor primario; Chroma y SkySoul en
    // contraste (cápsula sólida blanca, o negra en claro)
    readonly property color segThumb: tonalSel ? pc : chroma || glassy ? t : light ? "#FFFFFF" : s1
    readonly property color segText: tonalSel ? pcText : chroma || glassy ? bg : t
    // Selección en listas: Material el contenedor secundario; SkySoul una capa de cristal más clara; Chroma un
    // velo blanco tenue (con la marca roja a la izquierda)
    readonly property color selBg: glassy ? Qt.alpha("#FFFFFF", light ? 0.7 : 0.13) : chroma ? Qt.alpha(t, light ? 0.07 : 0.09) : sc
    readonly property color selText: glassy || chroma ? t : scText
    // Tarjetas (secciones de Ajustes): SkySoul cristal con borde · Chroma carbón · resto c.s3
    readonly property color card: st.card ?? (glassy ? fill2 : s3)
    readonly property int cardBorder: st.cardBorder ?? (glassy ? 1 : 0)
    // Chroma: lo activo invertido (como los ajustes rápidos de Nothing OS); el rojo queda para los detalles
    readonly property color fillOn: chroma ? t : p
    readonly property color fillOnText: chroma ? bg : pText
    // Chroma: la selección de las listas de navegación lleva una marca roja a la izquierda (Nothing)
    readonly property bool selPill: chroma
    readonly property color selPillColor: chroma ? accent2 : p
    // Sombras de los paneles (Glass): radio y desplazamiento según estilo y Ajustes › Apariencia › Sombras
    readonly property real shBlur: st.shBlur ?? (estilo === "flat" ? 14 : 26)
    readonly property real shY: st.shY ?? (estilo === "flat" ? 3 : 8)
    readonly property real shBigBlur: st.shBigBlur ?? 52
    readonly property real shBigY: st.shBigY ?? 18
    readonly property real shSpread: st.shSpread ?? (estilo === "flat" ? -2 : 0)

    // Tipografía y movimiento
    readonly property string font: data.font ?? "Inter"
    // Tipografía de los textos grandes (Txt con size ≥ 17: relojes, cifras, títulos): de puntos en Chroma
    // (Doto, en assets/fonts, OFL); el resto, la normal
    FontLoader { id: dotoFont; source: Qt.resolvedUrl("assets/fonts/Doto.ttf") }
    readonly property string displayFont: chroma && dotoFont.status === FontLoader.Ready ? dotoFont.name : font
    readonly property int displayWeight: chroma ? Font.Bold : Font.Normal
    // Títulos de sección como etiquetas en mayúsculas espaciadas («01  AGENT STATUS»): monoespaciadas en Chroma
    readonly property bool capsLabels: chroma
    readonly property string labelFont: chroma ? mono : font
    readonly property real labelSpacing: chroma ? 1.2 : 2.2
    readonly property string mono: "JetBrains Mono"
    readonly property real scale: data.fontScale ?? 1.0
    function px(n: real): real { return Math.round(n * scale * 2) / 2; }
    // Movimiento (Ajustes › Apariencia › Movimiento → hf-apply → theme.json motion): duraciones y curvas del
    // preajuste (Fluido · Equilibrado · Rápido · Mínimo · Ninguna) ya divididas por la velocidad elegida.
    // «Reducir movimiento» o animaciones apagadas → 0.
    readonly property var motion: data.motion ?? ({})
    readonly property string motionPreset: motion.preset ?? "fluido"
    readonly property bool still: reduceMotion || motionPreset === "ninguno"
    readonly property int dur: still ? 0 : (motion.dur ?? 260)            // transiciones de estado
    readonly property int durIn: still ? 0 : (motion.durIn ?? 420)        // aparición de paneles
    readonly property int durOut: still ? 0 : (motion.durOut ?? 180)      // cierre de paneles
    // Duración fija de un detalle (hover, pulsación, cambio de color) que sigue la velocidad elegida y se anula con
    // «Reducir movimiento»: Theme.ms(140)
    function ms(n: real): int { return still ? 0 : Math.round(n / (motion.speed || 1)); }
    // Curvas: «ease» desacelera al entrar; «easeIn» es la de aparición (con un leve rebote en Fluido, y en
    // SkySoul con Equilibrado); «easeOut» acelera al salir
    readonly property var easeSpring: [0.34, 1.36, 0.64, 1, 1, 1]
    readonly property var ease: motion.ease ?? [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeOut: motion.easeOut ?? [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var easeIn: motion.easeIn ?? (glassy ? easeSpring : ease)

    function alpha(col, a) { return Qt.alpha(col, a); }

    FileView {
        path: Paths.state + "/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} }
    }

    // Grafito · SkySoul, por si theme.json aún no existe
    QtObject {
        id: fallback
        readonly property var c: ({ bg: "#121314", s1: "#1A1C1E", s3: "#25272A", s4: "#2F3235", p: "#A9C1D9", onP: "#0E2A40",
            pc: "#2C3E50", onPc: "#D5E3F0", sc: "#353A40", onSc: "#E1E4E8", ter: "#C9B79C", t: "#E4E6E8", tv: "#AEB4BA",
            o: "#8A9097", ov: "#383C41" })
        readonly property var st: ({ estilo: "skysoul", blur: true, bg: "#571A1C1E", bgPanel: "#701A1C1E", bgPopup: "#851A1C1E",
            bg2: "#17E4E6E8", border: "#1FFFFFFF", borderWidth: 1, highlight: "#2EFFFFFF", glow: "#09FFFFFF",
            shadow: "#29000000", shadowBig: "#42000000", win: "#8F1A1C1E", barRad: 7, panelRad: 10, winRad: 8,
            ctlRad: 6, pill: false, roundK: 1.0, rimTop: "#6BFFFFFF", rimBottom: "#0FFFFFFF", sheen: "#12FFFFFF" })
    }
}
