// Ajustes › Red › VPN › Añadir: formulario de las VPN de empresa (FortiGate SSL VPN y GlobalProtect).
// Portal, usuario, autenticación (contraseña · SSO/SAML · certificado), aviso de 2FA y el programa que conecta
// («Automático» elige el mejor instalado: scripts/hf-vpn backends). Crea con «hf-vpn add … --auth …».
//   VpnCorpForm { type: <línea de «hf-vpn plugins»>; cmd: Paths.script("hf-vpn"); onCreate: args => …; onInstall: k => … }
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."
import "../../../components"

ColumnLayout {
    id: root
    property var type: null              // {key, label, backends:[…], auto:{password,saml,cert}, agent, webview, note}
    property string cmd: ""
    property bool editor: false
    signal create(var args)
    signal install(string key)
    signal advanced()
    spacing: 8

    readonly property bool forti: type?.key === "fortinet"
    property string auth: "password"
    property string backend: "auto"
    property bool otp: false
    readonly property var backends: (type?.backends ?? []).filter(b => b.auth.includes(auth))
    readonly property string autoKey: type?.auto?.[auth] ?? ""
    readonly property string chosen: backend === "auto" ? autoKey : backend
    readonly property var chosenB: (type?.backends ?? []).find(b => b.key === chosen) ?? null
    readonly property bool ready: chosenB !== null && chosenB.installed
    readonly property bool gpSsoGap: !forti && auth === "saml" && chosen === "nm-oc" && !(type?.backends ?? []).find(b => b.key === "gpclient")?.installed && !type?.agent
    readonly property var authLabel: ({ password: "usuario y contraseña", saml: "SSO", cert: "certificado" })

    function reset() { nameF.text = ""; hostF.text = ""; userF.text = ""; certF.text = ""; realmF.text = ""; auth = (Quickshell.env("HF_DEV_VPN_ADD") ?? "").split(":")[1] || "password"; backend = "auto"; otp = false; }
    onTypeChanged: reset()
    function submit() {
        const a = ["add", type.key, nameF.text.trim() || nameF.placeholder, hostF.text.trim(), userF.text.trim(), "--auth", auth, "--backend", chosen];
        if (otp && auth !== "saml") a.push("--otp");
        if (auth === "cert") a.push("--cert", certF.text.trim());
        if (forti && realmF.text.trim()) a.push("--realm", realmF.text.trim());
        root.create(a);
    }
    Process {
        id: pick
        command: [root.cmd, "pick-cert"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p) certF.text = p; } }
    }

    LabeledRow { label: "Nombre"; Field { id: nameF; icon: ""; placeholder: root.forti ? "VPN de la oficina" : "GlobalProtect" } }
    LabeledRow {
        label: root.forti ? "Servidor" : "Portal"
        hint: root.forti ? "FortiGate" : "Palo Alto"
        Field { id: hostF; icon: ""; placeholder: root.forti ? "vpn.empresa.com:10443 (el puerto si no es 443)" : "portal.empresa.com (o la puerta de enlace)" }
    }
    LabeledRow { label: "Usuario"; Field { id: userF; icon: ""; placeholder: root.auth === "saml" ? "opcional · con SSO lo pide tu empresa" : "opcional · se pide al conectar si lo dejas vacío" } }
    LabeledRow {
        label: "Autenticación"
        Seg {
            model: [["password", "Usuario y contraseña"], ["saml", "SSO/SAML en el navegador"], ["cert", "Certificado"]]
            current: root.auth
            onPicked: k => { root.auth = k; if (root.backend !== "auto" && !root.backends.find(b => b.key === root.backend)) root.backend = "auto"; }
        }
    }
    LabeledRow {
        visible: root.auth === "cert"
        label: "Certificado"
        RowLayout {
            spacing: 8
            Field { id: certF; Layout.fillWidth: true; icon: ""; placeholder: "archivo .p12/.pfx o .pem que te dio TI" }
            Button { text: "Elegir…"; onClicked: { pick.running = false; pick.running = true; } }
        }
    }
    LabeledRow {
        visible: root.forti
        label: "Realm"
        Field { id: realmF; icon: ""; placeholder: "opcional · solo si tu empresa te lo indicó" }
    }
    LabeledRow {
        visible: root.auth !== "saml"
        label: "Código 2FA"
        RowLayout {
            spacing: 10
            Chip { text: "Pide código 2FA/OTP"; on: root.otp; onClicked: root.otp = !root.otp }
            Txt {
                Layout.fillWidth: true; muted: true; size: 11.5; wrapMode: Text.WordWrap
                text: root.otp ? "Se pide al conectar: FortiToken, SMS, correo o una app de códigos." : "Si tu empresa usa FortiToken, SMS o una app de códigos."
            }
        }
    }
    LabeledRow {
        label: "Programa"
        Dropdown {
            model: [["auto", "Automático" + (root.autoKey ? " · " + ((root.type?.backends ?? []).find(b => b.key === root.autoKey)?.label ?? root.autoKey) : " · ninguno instalado")]]
                .concat(root.backends.map(b => [b.key, b.label + (b.installed ? "" : " · sin instalar")]))
            current: root.backend
            onPicked: k => root.backend = k
        }
    }
    Txt {
        Layout.fillWidth: true; Layout.leftMargin: 130; wrapMode: Text.WordWrap; muted: true; size: 11.5
        visible: text !== ""
        text: !root.chosenB ? "" : (root.auth === "saml" && root.chosenB.descSso ? root.chosenB.descSso : root.chosenB.desc) + "."
            + (root.chosenB.root ? "" : root.auth === "saml"
                ? (root.forti ? " Se abre la página de inicio de sesión de tu empresa y, al terminar, NetworkManager levanta el túnel." : " gpclient abre el inicio de sesión de tu empresa y NetworkManager levanta el túnel.")
                : (root.otp ? " La contraseña y el código se piden" : " La contraseña se pide")
                    + (root.type?.agent ? " en la ventana de NetworkManager." : " en una terminal al conectar (no hay agente de NetworkManager como nm-applet)."))
    }
    // falta un programa para lo elegido
    RowLayout {
        visible: !root.ready || root.gpSsoGap
        Layout.fillWidth: true
        Layout.leftMargin: 130
        spacing: 10
        Txt {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; size: 12
            text: root.gpSsoGap ? "Para el SSO de GlobalProtect hace falta gpclient (globalprotect-openconnect)."
                : root.chosenB ? "Falta «" + root.chosenB.label + "» para conectarte con " + root.authLabel[root.auth] + "."
                : "No hay ningún programa instalado para esta VPN con " + root.authLabel[root.auth] + "."
            color: Theme.t
        }
        Button { kind: "primary"; text: "Instalar"; onClicked: root.install(root.type.key) }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 130
        spacing: 10
        Button {
            kind: "primary"; text: "Crear"
            enabled: root.ready && hostF.text.trim() !== "" && (root.auth !== "cert" || certF.text.trim() !== "")
            onClicked: root.submit()
        }
        Button { visible: root.editor && root.chosen.startsWith("nm-"); kind: "link"; text: "Opciones avanzadas en el editor"; onClicked: root.advanced() }
        Item { Layout.fillWidth: true }
    }
    Txt {
        visible: (root.type?.note ?? "") !== ""
        Layout.fillWidth: true; Layout.leftMargin: 130; wrapMode: Text.WordWrap; muted: true; size: 11.5
        text: root.type?.note ?? ""
    }
}
