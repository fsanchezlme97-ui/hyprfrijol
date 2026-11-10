.pragma library
// Resaltado de sintaxis ligero para los bloques de código del asistente (AiRich.qml). Sin dependencias:
// un tokenizador por expresiones regulares por familia de lenguaje que devuelve HTML para Text.RichText.
//   html(code, lang, light) → "<div style='white-space:pre-wrap'>…</div>"
//   family(lang)            → "sql" | "sh" | "json" | "diff" | "conf" | "py" | "markup" | "lua" | "clike"
// Familias: SQL, terminal (bash/zsh/fish/console), JSON, diff, configuración (yaml/toml/ini/env), Python,
// HTML/XML, Lua y «estilo C» para el resto (js/ts/qml/java/c/cpp/go/rust/css/php…). Lenguaje vacío → estilo C.

var PALETTES = {
    dark:  { kw: "#bb9af7", str: "#9ece6a", num: "#ff9e64", com: "#7a82a8", fn: "#7aa2f7", type: "#2ac3de",
             vari: "#e0af68", flag: "#7dcfff", key: "#73daca", add: "#9ece6a", del: "#f7768e", meta: "#8a90b0", tag: "#f7768e" },
    light: { kw: "#8250df", str: "#0a7f3f", num: "#b35900", com: "#6e7781", fn: "#0550ae", type: "#0e7490",
             vari: "#953800", flag: "#0969da", key: "#116329", add: "#116329", del: "#cf222e", meta: "#6e7781", tag: "#cf222e" }
};

function words(s) { var o = {}; s.split(/\s+/).forEach(function (w) { if (w) o[w] = true; }); return o; }

var KW = {
    clike: words("break case catch class const continue debugger default delete do else enum export extends false finally for " +
        "function if import in instanceof let new null return super switch this throw true try typeof var void while with yield " +
        "async await static public private protected interface implements package readonly type namespace abstract as from of " +
        "fn mut pub impl struct trait use mod match loop where self Self crate move ref unsafe dyn go func defer chan map range " +
        "select fallthrough property signal alias required component int float double char bool boolean long short unsigned " +
        "signed string auto nil undefined override virtual final sealed goto sizeof template typename using inline extern " +
        "volatile register union typedef echo include require fun val object companion when is internal lateinit"),
    py: words("False None True and as assert async await break class continue def del elif else except finally for from " +
        "global if import in is lambda nonlocal not or pass raise return try while with yield match case self print"),
    sql: words("select from where and or not insert into values update set delete create table drop alter add column index " +
        "view join inner left right full outer cross on as group by order having limit offset union all distinct case when then " +
        "else end is null like ilike in between exists primary key foreign references default unique check constraint begin " +
        "commit rollback transaction returning with recursive asc desc if replace database schema grant revoke truncate " +
        "natural using over partition window cast true false trigger procedure function returns language declare execute " +
        "fetch cursor for each row before after instead of do nothing conflict materialized temporary temp vacuum analyze explain"),
    sqlType: words("int integer bigint smallint tinyint serial bigserial text varchar char character boolean bool date time " +
        "timestamp timestamptz interval numeric decimal real float double precision json jsonb uuid blob bytea money"),
    sh: words("if then else elif fi for while until do done case esac in function select return break continue local export " +
        "readonly declare unset source alias set shift trap eval exit time"),
    shPass: words("sudo doas env exec time nohup xargs command builtin then do else elif"),
    lua: words("and break do else elseif end false for function goto if in local nil not or repeat return then true until while self"),
    conf: words("true false yes no on off null none")
};

var NUM = "\\b(?:0[xX][\\da-fA-F_]+|0[bB][01_]+|\\d[\\d_]*(?:\\.\\d+)?(?:[eE][+-]?\\d+)?)\\b";
var DQ = "\"(?:[^\"\\\\\\n]|\\\\.)*\"", SQ = "'(?:[^'\\\\\\n]|\\\\.)*'", BQ = "`(?:[^`\\\\]|\\\\.)*`";
var WORD = "[A-Za-z_][\\w]*";

// Reglas por familia: [clase, fuente]. Sin grupos de captura dentro (solo (?:…)).
var RULES = {
    clike: [["com", "\\/\\/[^\\n]*"], ["com", "\\/\\*[\\s\\S]*?(?:\\*\\/|$)"], ["com", "^\\s*#(?:!|include|define|if|ifdef|ifndef|endif|else|pragma|import)[^\\n]*"],
            ["str", BQ], ["str", DQ], ["str", SQ], ["meta", "@[A-Za-z_][\\w.]*"], ["num", NUM], ["word", WORD]],
    py:    [["com", "#[^\\n]*"], ["str", "[rRbBfFuU]{0,2}(?:\"\"\"[\\s\\S]*?(?:\"\"\"|$)|'''[\\s\\S]*?(?:'''|$))"],
            ["str", "[rRbBfFuU]{0,2}" + DQ], ["str", "[rRbBfFuU]{0,2}" + SQ], ["meta", "@[A-Za-z_][\\w.]*"], ["num", NUM], ["word", WORD]],
    sql:   [["com", "--[^\\n]*"], ["com", "#[^\\n]*"], ["com", "\\/\\*[\\s\\S]*?(?:\\*\\/|$)"], ["str", SQ],
            ["key", DQ], ["key", "`[^`\\n]*`"], ["vari", "[:@$]\\w+|\\?"], ["num", NUM], ["word", WORD]],
    sh:    [["meta", "^[ \\t]*[$%❯›»][ \\t]"], ["com", "(?:^|[ \\t])#[^\\n]*"], ["str", SQ], ["str", DQ],
            ["vari", "\\$\\{[^}\\n]*\\}|\\$\\(|\\$[A-Za-z_]\\w*|\\$[0-9#?@*!$-]"], ["op", "\\|\\||&&|[|;&()]"],
            ["flag", "(?:^|[ \\t])--?[A-Za-z0-9][\\w-]*(?:=[^\\s]*)?"], ["num", "\\b\\d+\\b"], ["word", "[A-Za-z_.\\/~][\\w.\\/~+:-]*"]],
    json:  [["com", "\\/\\/[^\\n]*"], ["key", DQ + "(?=\\s*:)"], ["str", DQ], ["num", "-?" + NUM], ["word", WORD]],
    diff:  [["meta", "^(?:@@[^\\n]*|diff [^\\n]*|index [^\\n]*)"], ["add", "^(?:\\+\\+\\+[^\\n]*|\\+[^\\n]*)"], ["del", "^(?:---[^\\n]*|-[^\\n]*)"]],
    conf:  [["com", "^[ \\t]*[#;][^\\n]*"], ["com", "[ \\t]#[^\\n]*"], ["type", "^[ \\t]*\\[[^\\]\\n]*\\]"],
            ["key", "^[ \\t]*-?[ \\t]*[\\w.\"'-]+(?=[ \\t]*[:=])"], ["str", DQ], ["str", SQ], ["vari", "\\$\\{[^}\\n]*\\}|\\$\\w+"], ["num", NUM], ["word", WORD]],
    markup:[["com", "<!--[\\s\\S]*?(?:-->|$)"], ["tag", "<\\/?[A-Za-z][\\w:.-]*|\\/?>"], ["str", DQ], ["str", SQ], ["key", "\\b[A-Za-z_:][\\w:.-]*(?==)"]],
    lua:   [["com", "--\\[\\[[\\s\\S]*?(?:\\]\\]|$)"], ["com", "--[^\\n]*"], ["str", "\\[\\[[\\s\\S]*?(?:\\]\\]|$)"], ["str", DQ], ["str", SQ], ["num", NUM], ["word", WORD]]
};

var ALIAS = {
    sql: "sql", mysql: "sql", postgresql: "sql", postgres: "sql", psql: "sql", pgsql: "sql", sqlite: "sql", plsql: "sql", tsql: "sql", mariadb: "sql",
    bash: "sh", sh: "sh", zsh: "sh", fish: "sh", shell: "sh", console: "sh", terminal: "sh", shellsession: "sh", ksh: "sh", nu: "sh", powershell: "sh", ps1: "sh",
    json: "json", jsonc: "json", json5: "json", geojson: "json",
    diff: "diff", patch: "diff",
    yaml: "conf", yml: "conf", toml: "conf", ini: "conf", conf: "conf", cfg: "conf", properties: "conf", env: "conf", dotenv: "conf", desktop: "conf", systemd: "conf", hyprlang: "conf",
    python: "py", py: "py", python3: "py",
    html: "markup", xml: "markup", svg: "markup", vue: "markup", xhtml: "markup", plist: "markup",
    lua: "lua"
};

function family(lang) { return ALIAS[String(lang || "").toLowerCase()] || "clike"; }

var cache = {};
function compiled(fam) {
    if (!cache[fam]) {
        var r = RULES[fam];
        cache[fam] = { cls: r.map(function (x) { return x[0]; }), re: new RegExp(r.map(function (x) { return "(" + x[1] + ")"; }).join("|"), "gm") };
    }
    return cache[fam];
}

function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

function html(code, lang, light) {
    var src = String(code || "");
    var wrap = function (body) { return "<div style='white-space:pre-wrap'>" + body + "</div>"; };
    if (src.length > 60000) return wrap(esc(src));            // respuestas enormes: sin colores, pero rápido
    var fam = family(lang), pal = light ? PALETTES.light : PALETTES.dark, c = compiled(fam);
    var kw = fam === "sql" ? KW.sql : fam === "py" ? KW.py : fam === "lua" ? KW.lua : fam === "conf" || fam === "json" ? KW.conf : KW.clike;
    var out = [], last = 0, m, expectCmd = true;              // expectCmd: en terminal, la siguiente palabra es un comando
    var span = function (cls, text) {
        var color = pal[cls];
        if (!color) return esc(text);
        return "<span style='color:" + color + (cls === "com" ? ";font-style:italic" : "") + "'>" + esc(text) + "</span>";
    };
    c.re.lastIndex = 0;
    while ((m = c.re.exec(src)) !== null) {
        if (m[0] === "") { c.re.lastIndex++; continue; }
        var gap = src.slice(last, m.index);
        if (gap) { out.push(esc(gap)); if (gap.indexOf("\n") >= 0) expectCmd = true; }
        var i = 1; while (i < m.length && m[i] === undefined) i++;
        var cls = c.cls[i - 1], tok = m[0];
        if (cls === "word") {
            var next = src.charAt(c.re.lastIndex), lw = tok.toLowerCase();
            if (fam === "sh") {
                if (KW.sh[tok] && expectCmd) { cls = "kw"; expectCmd = /^(if|then|else|elif|do|while|until|time)$/.test(tok); }
                else if (expectCmd) { cls = "fn"; expectCmd = !!KW.shPass[tok]; }
                else cls = "";
            } else if (fam === "sql") {
                cls = KW.sql[lw] ? "kw" : KW.sqlType[lw] ? "type" : next === "(" ? "fn" : "";
            } else if (fam === "conf" || fam === "json") {
                cls = KW.conf[lw] ? "kw" : "";
            } else {
                cls = kw[tok] ? "kw" : next === "(" ? "fn" : (fam === "clike" && /^[A-Z][a-z0-9]\w*$/.test(tok)) ? "type" : "";
            }
        } else if (fam === "sh") {
            if (cls === "op" || (cls === "vari" && tok === "$(")) expectCmd = true;
            else if (cls === "meta") expectCmd = true;
            else if (cls !== "com") expectCmd = false;
        }
        if (cls === "op") cls = "";
        out.push(span(cls, tok));
        last = c.re.lastIndex;
        if (tok.indexOf("\n") >= 0 && fam === "sh") expectCmd = true;
    }
    out.push(esc(src.slice(last)));
    return wrap(out.join(""));
}
