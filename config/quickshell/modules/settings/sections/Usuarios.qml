// Ajustes › Usuarios — tu cuenta (avatar ~/.face + AccountsService, nombre completo con SetRealName,
// contraseña con passwd en una terminal), inicio automático (greetd [initial_session]) y el resto de cuentas
// (getent passwd, UID 1000–59999): crear (useradd + passwd en terminal), quitar (userdel) y administrador
// (grupo wheel). Todo lo que necesita permisos pasa por pkexec o sudo en una terminal, con confirmación.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../.."
import "../../../components"
import "../../../services"
import "../ui"

RowLayout {
    id: root
    spacing: 12
    implicitHeight: Math.max(left.implicitHeight, right.implicitHeight)
    property var me: ({})               // { name, uid, real, icon, admin, shell }
    property var users: []              // [{ name, uid, real, home, admin, icon }]
    property string greetd: ""          // "", "enabled"…
    property string autoUser: ""
    property string sessionCmd: ""
    property bool adding: false
    property bool newAdmin: false
    property int faceTick: 0
    property bool hasFace: false
    // ~/.face (lo que se acaba de elegir) o el icono de AccountsService; el «#» alterno fuerza recargar la imagen
    readonly property string faceSrc: { const p = hasFace ? Paths.home + "/.face" : (me.icon ?? ""); return p ? p + (faceTick % 2 ? "#" : "") : ""; }
    readonly property int admins: users.filter(u => u.admin).length

    function refresh() { probe.running = false; probe.running = true; }
    Timer { id: later; interval: 1500; onTriggered: root.refresh() }
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "acc() { timeout 2 busctl --system get-property org.freedesktop.Accounts \"/org/freedesktop/Accounts/User$1\" org.freedesktop.Accounts.User \"$2\" 2>/dev/null | sed 's/^[a-z] //; s/^\"//; s/\"$//'; }; ic() { p=$(acc $1 IconFile); [ -s \"$p\" ] && [ -r \"$p\" ] && echo \"$p\"; }; "
            + "u=$(id -un); i=$(id -u); printf 'me\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$u\" \"$i\" \"$(getent passwd \"$u\" | cut -d: -f5 | cut -d, -f1)\" \"$(ic $i)\" \"$(id -nG | tr ' ' ',')\"; "
            + "getent passwd | awk -F: '$3>=1000 && $3<60000' | while IFS=: read -r n _ id _ g h _; do "
            + "  printf 'u\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$n\" \"$id\" \"${g%%,*}\" \"$h\" \"$(id -nG \"$n\" 2>/dev/null | tr ' ' ',')\" \"$(ic $id)\"; done; "
            + "test -s \"$HOME/.face\" && echo face:yes; echo greetd:$(systemctl is-enabled greetd 2>/dev/null); "
            + "awk '/^\\[initial_session\\]/{s=1;next} /^\\[/{s=0} s && /^ *user *=/{gsub(/.*= *\"?|\"? *$/,\"\"); print \"auto:\"$0}' /etc/greetd/config.toml 2>/dev/null; "
            + "f=/usr/share/wayland-sessions/hyprfrijol.desktop; [ -f \"$f\" ] || f=/usr/share/wayland-sessions/hypr-liquid.desktop; [ -f \"$f\" ] || f=/usr/share/wayland-sessions/hyprland.desktop; sed -n 's/^Exec=/exec:/p' \"$f\" 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                const m = (l.find(x => x.startsWith("me\t")) ?? "me").split("\t");
                const groups = (m[5] ?? "").split(",");
                root.me = { name: m[1] ?? "", uid: Number(m[2] ?? 0), real: m[3] ?? "", icon: m[4] ?? "", admin: groups.includes("wheel") || groups.includes("sudo") };
                root.users = l.filter(x => x.startsWith("u\t")).map(x => { const f = x.split("\t"); const g = (f[5] ?? "").split(","); return { name: f[1], uid: Number(f[2]), real: f[3], home: f[4], admin: g.includes("wheel") || g.includes("sudo"), icon: f[6] ?? "" }; });
                root.hasFace = l.includes("face:yes");
                root.greetd = (l.find(x => x.startsWith("greetd:")) ?? "greetd:").slice(7);
                root.autoUser = (l.find(x => x.startsWith("auto:")) ?? "auto:").slice(5);
                root.sessionCmd = (l.find(x => x.startsWith("exec:")) ?? "exec:").slice(5);
                if (!nameField.input.activeFocus) nameField.text = root.me.real;
            }
        }
    }

    // ---------- acciones ----------
    function setRealName(n) {
        Quickshell.execDetached(["sh", "-c", "busctl --system call --allow-interactive-authorization org.freedesktop.Accounts \"/org/freedesktop/Accounts/User$(id -u)\" org.freedesktop.Accounts.User SetRealName s \"$1\" || pkexec chfn -f \"$1\" \"$(id -un)\"", "sh", n]);
        later.restart();
    }
    Process {
        id: pickFace
        // Elige una imagen, la recorta a 256×256 si hay ImageMagick y la guarda en ~/.face (bloqueo, ajustes rápidos)
        // y en AccountsService (pantalla de inicio de sesión).
        command: ["sh", "-c", "f=$(zenity --file-selection --title='Elige tu foto' --file-filter='Imágenes | *.png *.jpg *.jpeg *.webp *.gif *.bmp' 2>/dev/null) || exit 1; [ -f \"$f\" ] || exit 1; "
            + "if command -v magick >/dev/null; then magick \"$f\"'[0]' -auto-orient -thumbnail '256x256^' -gravity center -extent 256x256 png:\"$HOME/.face\"; else cp -f \"$f\" \"$HOME/.face\"; fi; "
            + "ln -sf .face \"$HOME/.face.icon\"; busctl --system call --allow-interactive-authorization org.freedesktop.Accounts \"/org/freedesktop/Accounts/User$(id -u)\" org.freedesktop.Accounts.User SetIconFile s \"$HOME/.face\" >/dev/null 2>&1; echo ok"]
        stdout: StdioCollector { onStreamFinished: if (text.includes("ok")) { root.faceTick++; later.restart(); } }
    }
    function removeFace() {
        Quickshell.execDetached(["sh", "-c", "rm -f \"$HOME/.face\" \"$HOME/.face.icon\"; busctl --system call --allow-interactive-authorization org.freedesktop.Accounts \"/org/freedesktop/Accounts/User$(id -u)\" org.freedesktop.Accounts.User SetIconFile s ''"]);
        faceTick++; later.restart();
    }
    function setAutoLogin(on) {
        Quickshell.execDetached(["pkexec", "sh", "-c", "f=/etc/greetd/config.toml; [ -f \"$f\" ] || exit 1; cp -f \"$f\" \"$f.antes-autologin\"; "
            + "awk '/^\\[initial_session\\]/{s=1;next} /^\\[/{s=0} !s' \"$f\" > \"$f.tmp\"; "
            + "[ \"$1\" = on ] && printf '\\n[initial_session]\\ncommand = \"%s\"\\nuser = \"%s\"\\n' \"$3\" \"$2\" >> \"$f.tmp\"; cat \"$f.tmp\" > \"$f\"; rm -f \"$f.tmp\"",
            "sh", on ? "on" : "off", me.name, sessionCmd]);
        later.restart();
    }
    function setAdmin(u, on) { Quickshell.execDetached(["pkexec", "gpasswd", on ? "-a" : "-d", u, "wheel"]); later.restart(); }
    function removeUser(u, files) { Quickshell.execDetached(["pkexec", "userdel"].concat(files ? ["-r"] : []).concat([u])); later.restart(); }
    readonly property string newName: newUser.text.trim()
    readonly property bool newValid: /^[a-z_][a-z0-9_-]{0,31}$/.test(newName) && !users.some(u => u.name === newName)
    function createUser() {
        const full = newFull.text.trim().replace(/'/g, "");
        Pkg.runInTerminal("sudo useradd -m" + (newAdmin ? " -G wheel" : "") + (full ? " -c '" + full + "'" : "") + " " + newName + " && echo 'Elige la contraseña de " + newName + ":' && sudo passwd " + newName, "Nuevo usuario");
        adding = false; newUser.text = ""; newFull.text = ""; newAdmin = false;
        later.restart();
        laterLong.restart();
    }
    Timer { id: laterLong; interval: 15000; onTriggered: root.refresh() }

    component Avatar: ClippingRectangle {
        id: av
        property string src: ""
        property string initial: ""
        property real d: 40
        implicitWidth: d; implicitHeight: d
        radius: d / 2
        color: Theme.pc
        Txt { anchors.centerIn: parent; visible: img.status !== Image.Ready; text: av.initial.charAt(0).toUpperCase(); size: av.d * 0.4; weight: Font.DemiBold; color: Theme.pcText }
        Image {
            id: img
            anchors.fill: parent
            source: av.src ? "file://" + av.src : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(av.d * 2, av.d * 2)
            cache: false
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    // ---------- tu cuenta ----------
    ColumnLayout {
        id: left
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 12
        Section {
            Layout.fillWidth: true
            title: "Tu cuenta"
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Item {
                    implicitWidth: 76; implicitHeight: 76
                    Avatar {
                        id: myFace
                        d: 76
                        // ~/.face primero (lo que se acaba de elegir); si no, el de AccountsService
                        src: root.faceSrc
                        initial: root.me.real || root.me.name || "?"
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pickFace.running = true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt { Layout.fillWidth: true; text: root.me.real || root.me.name || "…"; size: 17; weight: Font.DemiBold }
                    Txt { Layout.fillWidth: true; muted: true; text: (root.me.name ?? "") + " · " + (root.me.admin ? "Administrador" : "Usuario estándar") + " · UID " + (root.me.uid ?? "") }
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 8
                        Button { text: "Cambiar foto…"; onClicked: pickFace.running = true }
                        Button { kind: "link"; text: "Quitar foto"; visible: root.hasFace; onClicked: root.removeFace() }
                    }
                }
            }
            LabeledRow {
                label: "Nombre completo"; labelWidth: 120
                Field {
                    id: nameField
                    icon: ""
                    placeholder: "Tu nombre · Enter para guardar"
                    onAccepted: { const n = text.trim().replace(/[:,=]/g, ""); if (n && n !== root.me.real) root.setRealName(n); }
                }
            }
            LabeledRow {
                label: "Contraseña"; labelWidth: 120
                RowLayout {
                    spacing: 8
                    Txt { Layout.fillWidth: true; text: "••••••••"; muted: true }
                    Button { text: "Cambiar contraseña…"; onClicked: Pkg.runInTerminal("passwd", "Cambiar contraseña") }
                }
            }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "La foto se usa en la pantalla de bloqueo, los ajustes rápidos y el inicio de sesión. El nombre completo aparece al bloquear."
            }
        }
        Section {
            Layout.fillWidth: true
            title: "Inicio de sesión"
            SwRow {
                separator: false
                label: "Iniciar sesión automáticamente"
                sub: root.greetd !== "enabled" ? "solo con greetd (el inicio de sesión de HyprFrijol) · ahora no está activo"
                    : root.autoUser && root.autoUser !== root.me.name ? "ahora entra automáticamente «" + root.autoUser + "»"
                    : "al encender, entra sin pedir contraseña (greetd)"
                enabled: root.greetd === "enabled" && root.sessionCmd !== ""
                checked: root.autoUser === root.me.name && root.me.name !== ""
                onToggled: v => root.setAutoLogin(v)
            }
            Txt {
                visible: root.autoUser !== ""
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: "Cualquiera que encienda el equipo entra en tu sesión. Al cerrar sesión o bloquear, sí se pide la contraseña. Tu llavero (contraseñas guardadas) puede pedirte la contraseña al entrar."
            }
            RowLayout {
                Layout.topMargin: 2
                spacing: 4
                Button { kind: "link"; text: "Tiempo hasta bloquear (Energía)"; onClicked: Shell.open("ajustesapp", "energia") }
                Txt { text: "·"; color: Theme.p }
                Button { kind: "link"; text: "Bloqueo de pantalla (Privacidad)"; onClicked: Shell.open("ajustesapp", "privacidad") }
            }
        }
    }

    // ---------- otras cuentas ----------
    Section {
        id: right
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        title: "Usuarios del equipo"
        headerRight: Button { kind: root.adding ? "outline" : "primary"; text: root.adding ? "Cancelar" : "Añadir usuario"; onClicked: root.adding = !root.adding }
        ColumnLayout {
            visible: root.adding
            Layout.fillWidth: true
            spacing: 8
            LabeledRow { label: "Nombre completo"; labelWidth: 120; Field { id: newFull; icon: ""; placeholder: "p. ej. Ana García" } }
            LabeledRow {
                label: "Usuario"; labelWidth: 120
                hint: root.newName === "" || root.newValid ? "" : root.users.some(u => u.name === root.newName) ? "ya existe" : "minúsculas, sin espacios"
                Field {
                    id: newUser
                    icon: ""
                    placeholder: "p. ej. ana"
                    onAccepted: if (root.newValid) root.createUser()
                    Connections {
                        target: newFull.input
                        function onTextChanged() {
                            if (newUser.input.activeFocus) return;
                            newUser.text = newFull.text.trim().split(/\s+/)[0].toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9_-]/g, "");
                        }
                    }
                }
            }
            SwRow { label: "Administrador"; sub: "puede instalar programas y cambiar el sistema (grupo wheel)"; checked: root.newAdmin; onToggled: v => root.newAdmin = v }
            RowLayout {
                spacing: 8
                Button { kind: "primary"; text: "Crear usuario"; enabled: root.newValid; onClicked: root.createUser() }
                Txt { Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap; text: "Se abrirá una terminal para confirmar con tu contraseña y elegir la del nuevo usuario." }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
        }
        Repeater {
            model: root.users
            ColumnLayout {
                id: ur
                required property var modelData
                required property int index
                readonly property bool isMe: modelData.name === root.me.name
                Layout.fillWidth: true
                spacing: 6
                Rectangle { visible: ur.index > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.ov }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 12
                    Avatar { d: 38; src: ur.isMe ? root.faceSrc : ur.modelData.icon; initial: ur.modelData.real || ur.modelData.name }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: (ur.modelData.real || ur.modelData.name) + (ur.isMe ? " (tú)" : ""); weight: Font.DemiBold }
                        Txt { Layout.fillWidth: true; muted: true; size: 11.5; text: ur.modelData.name + " · " + (ur.modelData.admin ? "Administrador" : "Usuario estándar") + " · " + ur.modelData.home }
                    }
                    Txt { text: "Administrador"; muted: true; size: 11.5 }
                    Sw {
                        checked: ur.modelData.admin
                        // no dejar el equipo sin administradores
                        enabled: !(ur.modelData.admin && root.admins <= 1)
                        onToggled: v => root.setAdmin(ur.modelData.name, v)
                    }
                }
                RowLayout {
                    visible: !ur.isMe
                    Layout.fillWidth: true
                    Layout.leftMargin: 50
                    Layout.bottomMargin: 4
                    spacing: 8
                    Button { text: "Cambiar contraseña…"; h: 28; onClicked: Pkg.runInTerminal("sudo passwd " + ur.modelData.name, "Contraseña de " + ur.modelData.name) }
                    ConfirmButton { h: 28; text: "Quitar"; confirmText: "¿Quitar y conservar sus archivos?"; onConfirmed: root.removeUser(ur.modelData.name, false) }
                    ConfirmButton { h: 28; text: "Quitar y borrar archivos"; confirmText: "¿Borrar " + ur.modelData.home + "? Sí"; onConfirmed: root.removeUser(ur.modelData.name, true) }
                }
            }
        }
        Txt {
            Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
            text: "Los administradores pertenecen al grupo wheel y pueden usar sudo. Los cambios piden tu contraseña. No puedes quitarte a ti mismo ni dejar el equipo sin administradores."
        }
    }
}
