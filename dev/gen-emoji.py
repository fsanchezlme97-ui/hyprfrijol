#!/usr/bin/env python3
"""Genera config/emoji/emojis.json para el selector de emojis (vista «emojis», Super + .).

Fuente (sin conexión): los diccionarios CLDR de speech-dispatcher
  /usr/share/speech-dispatcher/locale/{es,en}/emojis.dic
que traen los emojis en el orden oficial de Unicode (grupos: caras, personas, animales…)
con su nombre en español y en inglés. Se descartan las variantes de tono de piel y los
símbolos que no son emoji. Se añaden palabras clave en español para los más usados.

  python3 dev/gen-emoji.py            → escribe config/emoji/emojis.json
Formato: {"groups": [["caras", "Caras y emociones"], …], "emojis": [[emoji, es, en, grupo, claves], …]}
"""
import json, pathlib, sys

SD = pathlib.Path("/usr/share/speech-dispatcher/locale")
OUT = pathlib.Path(__file__).resolve().parent.parent / "config/emoji/emojis.json"

GROUPS = [  # (id, título, primer emoji del grupo en el orden CLDR)
    ("caras", "Caras y emociones", "😀"),
    ("personas", "Personas y gestos", "👋"),
    ("naturaleza", "Animales y naturaleza", "🐵"),
    ("comida", "Comida y bebida", "🍇"),
    ("viajes", "Viajes y lugares", "🌍"),
    ("actividades", "Actividades", "🎃"),
    ("objetos", "Objetos", "👓"),
    ("simbolos", "Símbolos", "🏧"),
    ("banderas", "Banderas", "🏁"),
]

# Puntos de código que por defecto se ven como texto: necesitan U+FE0F para verse como emoji
TEXT_DEFAULT_SMP = {0x1F170, 0x1F171, 0x1F17E, 0x1F17F, 0x1F202, 0x1F237, 0x1F321, 0x1F324, 0x1F325, 0x1F326,
    0x1F327, 0x1F328, 0x1F329, 0x1F32A, 0x1F32B, 0x1F32C, 0x1F336, 0x1F37D, 0x1F396, 0x1F397, 0x1F399, 0x1F39A,
    0x1F39B, 0x1F39E, 0x1F39F, 0x1F3CB, 0x1F3CC, 0x1F3CD, 0x1F3CE, 0x1F3D4, 0x1F3D5, 0x1F3D6, 0x1F3D7, 0x1F3D8,
    0x1F3D9, 0x1F3DA, 0x1F3DB, 0x1F3DC, 0x1F3DD, 0x1F3DE, 0x1F3DF, 0x1F3F3, 0x1F3F5, 0x1F3F7, 0x1F43F, 0x1F441,
    0x1F4FD, 0x1F549, 0x1F54A, 0x1F56F, 0x1F570, 0x1F573, 0x1F574, 0x1F575, 0x1F576, 0x1F577, 0x1F578, 0x1F579,
    0x1F587, 0x1F58A, 0x1F58B, 0x1F58C, 0x1F58D, 0x1F590, 0x1F5A5, 0x1F5A8, 0x1F5B1, 0x1F5B2, 0x1F5BC, 0x1F5C2,
    0x1F5C3, 0x1F5C4, 0x1F5D1, 0x1F5D2, 0x1F5D3, 0x1F5DC, 0x1F5DD, 0x1F5DE, 0x1F5E1, 0x1F5E3, 0x1F5E8, 0x1F5EF,
    0x1F5F3, 0x1F5FA, 0x1F6CB, 0x1F6CD, 0x1F6CE, 0x1F6CF, 0x1F6E0, 0x1F6E1, 0x1F6E2, 0x1F6E3, 0x1F6E4, 0x1F6E5,
    0x1F6E9, 0x1F6F0, 0x1F6F3}
SKIP = {0x200D, 0xFE0F, 0x20E3} | set(range(0x1F3FB, 0x1F400))

def presentable(seq: str) -> str:
    out = []
    for ch in seq:
        cp = ord(ch)
        out.append(ch)
        if cp in SKIP:
            continue
        if cp < 0x1F000 and cp > 0x7F or cp in TEXT_DEFAULT_SMP:
            out.append("️")
    return "".join(out)

# Palabras clave en español (cómo se busca de verdad) para los más usados
KEYWORDS = {
    "😀": "feliz sonrisa", "😃": "feliz alegre", "😄": "feliz risa", "😁": "sonrisa dientes", "😆": "jaja risa",
    "😅": "uf sudor nervios jaja", "🤣": "jajaja muerto de risa lol", "😂": "jaja lol risa lagrimas", "🙂": "bien ok",
    "🙃": "ironia sarcasmo", "😉": "guiño complice", "😊": "contento timido", "😇": "angel inocente", "🥰": "amor enamorado",
    "😍": "amor enamorado ojos corazon", "🤩": "wow genial estrellas", "😘": "beso", "😋": "rico delicioso",
    "😛": "lengua broma", "😜": "loco broma", "🤪": "loco", "🤑": "dinero plata", "🤗": "abrazo", "🤭": "ups risita",
    "🤫": "silencio secreto", "🤔": "pensando duda hmm", "🤐": "callado secreto", "😐": "neutral serio", "😑": "meh",
    "😶": "sin palabras", "😏": "picaro", "😒": "aburrido molesto", "🙄": "ojos en blanco fastidio", "😬": "incomodo",
    "😌": "aliviado tranquilo", "😔": "triste pensativo", "😪": "sueño", "🤤": "babeando antojo", "😴": "dormir sueño zzz",
    "😷": "enfermo mascarilla", "🤒": "fiebre enfermo", "🤢": "asco nauseas", "🤮": "vomito asco", "🥵": "calor",
    "🥶": "frio", "😵": "mareado", "🤯": "explota cabeza mente", "🥳": "fiesta cumpleaños celebrar", "😎": "genial gafas cool",
    "🤓": "nerd estudioso", "😕": "confundido", "😟": "preocupado", "🙁": "triste", "😮": "sorpresa wow", "😲": "asombro",
    "🥺": "por favor suplica", "😢": "llorar triste", "😭": "llorar llanto", "😱": "miedo grito", "😖": "frustrado",
    "😞": "decepcionado", "😓": "sudor cansado", "😩": "agotado", "😫": "cansado", "🥱": "bostezo aburrido",
    "😤": "enojo resoplido", "😡": "enojado furia", "😠": "enojado", "🤬": "insultos furia", "😈": "diablo travieso",
    "💀": "muerto calavera jaja", "💩": "caca", "🤡": "payaso", "👻": "fantasma", "👽": "alien", "🤖": "robot bot ia",
    "❤": "corazon amor rojo", "🧡": "corazon naranja", "💛": "corazon amarillo", "💚": "corazon verde",
    "💙": "corazon azul", "💜": "corazon morado", "🖤": "corazon negro", "🤍": "corazon blanco", "💔": "corazon roto",
    "💕": "corazones amor", "💖": "corazon brillante", "💯": "cien perfecto", "💥": "explosion boom", "💫": "mareo",
    "💬": "mensaje chat", "💤": "dormir zzz", "👋": "hola adios saludo mano", "👌": "ok perfecto", "✌": "paz victoria",
    "🤞": "suerte dedos cruzados", "🤟": "te quiero", "🤘": "rock", "🤙": "llamame", "👈": "izquierda", "👉": "derecha",
    "👆": "arriba", "👇": "abajo", "👍": "ok bien si like pulgar", "👎": "mal no dislike", "✊": "puño fuerza",
    "👊": "puño golpe", "👏": "aplausos bravo", "🙌": "celebrar hurra", "🤝": "trato acuerdo apreton manos",
    "🙏": "gracias por favor rezar", "💪": "fuerza musculo gym", "👀": "mirar ojos", "🧠": "cerebro idea",
    "🔥": "fuego genial", "✨": "brillo magia", "⭐": "estrella", "🌟": "estrella brillante", "🎉": "fiesta celebrar confeti",
    "🎊": "fiesta confeti", "🎂": "pastel torta cumpleaños", "🎁": "regalo", "🏆": "trofeo ganar", "✅": "hecho listo check si",
    "❌": "no error cruz", "⚠": "advertencia cuidado", "❓": "pregunta", "❗": "importante exclamacion", "➕": "mas sumar",
    "➖": "menos", "🆗": "ok", "🆕": "nuevo", "🔔": "campana aviso", "📌": "fijar chincheta", "📎": "clip adjunto",
    "📅": "calendario fecha", "📆": "calendario", "⏰": "alarma despertador", "⌛": "espera tiempo", "📝": "nota escribir",
    "📄": "documento", "📁": "carpeta", "💻": "laptop portatil ordenador computadora", "🖥": "ordenador pc",
    "📱": "celular movil telefono", "☎": "telefono", "📞": "llamada telefono", "📧": "correo email", "✉": "carta sobre correo",
    "🔒": "candado seguro", "🔑": "llave clave", "💡": "idea bombilla foco", "🔧": "llave herramienta arreglar",
    "🛠": "herramientas", "⚙": "engranaje ajustes", "🔍": "buscar lupa", "📷": "camara foto", "🎵": "musica nota",
    "🎶": "musica", "🎮": "juego videojuego mando", "☕": "cafe", "🍺": "cerveza", "🍷": "vino", "🍕": "pizza",
    "🍔": "hamburguesa", "🌮": "taco", "🍎": "manzana", "🚀": "cohete lanzar rapido", "✈": "avion viaje", "🚗": "auto coche carro",
    "🏠": "casa hogar", "🌍": "mundo tierra planeta", "☀": "sol", "🌙": "luna noche", "🌧": "lluvia", "❄": "nieve frio",
    "🌈": "arcoiris", "🐶": "perro", "🐱": "gato", "🦄": "unicornio", "🌹": "rosa flor", "🌸": "flor cerezo",
    "🍀": "trebol suerte", "💰": "dinero plata bolsa", "💸": "dinero gastar", "📈": "subida crecimiento grafico",
    "📉": "bajada grafico", "🙈": "no ver mono verguenza", "🙉": "no oir", "🙊": "no hablar", "👑": "corona rey reina",
}

def load(lang):
    rows = []
    for line in (SD / lang / "emojis.dic").read_text(encoding="utf-8-sig").splitlines():
        parts = line.rstrip("\r").split("\t")
        if len(parts) >= 2 and parts[0] and not parts[0].startswith("#"):
            rows.append((parts[0], parts[1]))
    return rows

def main():
    if not (SD / "es/emojis.dic").exists():
        sys.exit("No encuentro los diccionarios de speech-dispatcher (paquete speech-dispatcher).")
    en_rows = load("en")
    es = dict(load("es"))
    order = [e for e, _ in en_rows]
    starts = {g[2]: i for i, g in enumerate(GROUPS)}
    first = order.index(GROUPS[0][2])
    end = order.index("🏁") + 12  # banderas especiales (arcoíris, pirata…)
    out, seen, g = [], set(), 0
    def add(e, name_en, gi):
        if e in seen or any(0x1F3FB <= ord(c) <= 0x1F3FF for c in e):
            return
        if len(e) == 1 and (0x1F9B0 <= ord(e) <= 0x1F9B3):  # componentes de pelo sueltos
            return
        seen.add(e)
        es_name = es.get(e, name_en)
        es_name = es_name[0].lower() + es_name[1:] if es_name.startswith("Bandera") else es_name
        out.append([presentable(e), es_name, name_en, GROUPS[gi][0], KEYWORDS.get(e, "")])
    for e, name in en_rows[first:end]:
        if e in starts:
            g = starts[e]
        if g == len(GROUPS) - 1 and not ("flag" in name or e == "🏁"):
            continue
        add(e, name, g)
    # Banderas de países (después de las variantes de tono de piel en el diccionario)
    for e, name in en_rows:
        if name.startswith("flag ") and all(0x1F1E6 <= ord(c) <= 0x1F1FF for c in e):
            add(e, name, len(GROUPS) - 1)
    # Teclas (no están en el diccionario)
    for k, n in [("#", "number sign"), ("*", "asterisk")] + [(str(i), f"digit {i}") for i in range(10)]:
        e = k + "️⃣"
        if e not in seen:
            seen.add(e)
            out.append([e, "tecla " + k, "keycap " + n, "simbolos", ""])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = {"groups": [[g[0], g[1]] for g in GROUPS], "emojis": out}
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{len(out)} emojis → {OUT}")

main()
