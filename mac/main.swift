// Santoro Mail — app nativa para Mac (envoltorio WebKit de la web app).
// Compilar: ./build.sh   →  ~/Applications/Santoro Mail.app
import Cocoa
import WebKit
import UserNotifications

let APP_URL = URL(string: "https://hanif.jamalhanif2002.workers.dev/")!
let IN_APP_HOSTS = ["hanif.jamalhanif2002.workers.dev", "mail.hanifhawlader.com",
                    "login.microsoftonline.com", "login.live.com", "login.microsoft.com",
                    "aadcdn.msftauth.net", "aadcdn.msauth.net", "account.live.com"]

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate,
                         WKScriptMessageHandler, UNUserNotificationCenterDelegate, NSWindowDelegate {
    var window: NSWindow!
    var web: WKWebView!

    func applicationDidFinishLaunching(_ n: Notification) {
        buildMenu()
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()                       // la sesión se queda guardada
        cfg.userContentController.add(self, name: "santoro")    // puente JS → Mac (avisos, número en el Dock)
        cfg.preferences.setValue(true, forKey: "developerExtrasEnabled")
        cfg.applicationNameForUserAgent = "SantoroMailMac/1.0 Safari/605.1.15"

        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.setValue(false, forKey: "drawsBackground")

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1360, height: 860),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "Santoro Mail"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 420, height: 560)
        window.backgroundColor = NSColor(red: 0.969, green: 0.961, blue: 0.914, alpha: 1)
        window.contentView = web
        window.delegate = self
        window.setFrameAutosaveName("SantoroMailMain")
        if !window.setFrameUsingName("SantoroMailMain") { window.center() }
        window.makeKeyAndOrderFront(nil)
        web.load(URLRequest(url: APP_URL))

        let c = UNUserNotificationCenter.current()
        c.delegate = self
        c.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        NSApp.activate(ignoringOtherApps: true)
    }

    // cerrar la ventana no cierra la app (como Mail); clic en el Dock la vuelve a abrir
    func windowShouldClose(_ s: NSWindow) -> Bool { window.orderOut(nil); return false }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows f: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil); return true
    }

    // ---- JS → Mac
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let d = m.body as? [String: Any], let type = d["type"] as? String else { return }
        if type == "badge" {
            let n = d["n"] as? Int ?? 0
            NSApp.dockTile.badgeLabel = n > 0 ? String(n) : nil
        } else if type == "notify" {
            let c = UNMutableNotificationContent()
            c.title = d["title"] as? String ?? "Santoro Mail"
            c.body = d["body"] as? String ?? ""
            c.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
        }
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h(NSApp.isActive ? [] : [.banner, .sound])
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse,
                                withCompletionHandler h: @escaping () -> Void) {
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); h()
    }

    // ---- enlaces: los de fuera se abren en el navegador
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler h: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let u = a.request.url else { return h(.allow) }
        if u.scheme == "mailto" { NSWorkspace.shared.open(u); return h(.cancel) }
        let host = u.host ?? ""
        let inApp = u.scheme == "about" || u.scheme == "blob" || u.scheme == "data" || IN_APP_HOSTS.contains(where: { host == $0 || host.hasSuffix("." + $0) })
        // solo los clics del usuario en enlaces de fuera van al navegador; las redirecciones
        // (Microsoft → GoDaddy → Microsoft → app) se quedan dentro para que el login funcione
        if !inApp && a.navigationType == .linkActivated && a.targetFrame?.isMainFrame != false { NSWorkspace.shared.open(u); return h(.cancel) }
        h(.allow)
    }
    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? {
        if let u = a.request.url { NSWorkspace.shared.open(u) }
        return nil
    }
    // subir fotos (perfil, adjuntos)
    func webView(_ w: WKWebView, runOpenPanelWith p: WKOpenPanelParameters, initiatedByFrame f: WKFrameInfo, completionHandler h: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = p.allowsMultipleSelection; panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { r in h(r == .OK ? panel.urls : nil) }
    }
    func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler h: @escaping () -> Void) {
        let a = NSAlert(); a.messageText = m; a.runModal(); h()
    }
    func webView(_ w: WKWebView, runJavaScriptConfirmPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler h: @escaping (Bool) -> Void) {
        let a = NSAlert(); a.messageText = m; a.addButton(withTitle: "OK"); a.addButton(withTitle: "Cancelar"); h(a.runModal() == .alertFirstButtonReturn)
    }

    // ---- menús (Editar es imprescindible para copiar/pegar)
    @objc func reload() { web.reload() }
    @objc func compose() { web.evaluateJavaScript("typeof openCompose==='function'&&openCompose()") }
    @objc func home() { web.load(URLRequest(url: APP_URL)) }
    func buildMenu() {
        let main = NSMenu()
        func item(_ t: String, _ s: Selector?, _ k: String, _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let i = NSMenuItem(title: t, action: s, keyEquivalent: k); i.keyEquivalentModifierMask = mods; return i
        }
        let app = NSMenu()
        app.addItem(item("Acerca de Santoro Mail", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""))
        app.addItem(.separator())
        app.addItem(item("Ocultar Santoro Mail", #selector(NSApplication.hide(_:)), "h"))
        app.addItem(item("Salir de Santoro Mail", #selector(NSApplication.terminate(_:)), "q"))
        let file = NSMenu(title: "Archivo")
        file.addItem(item("Nuevo correo", #selector(compose), "n"))
        file.addItem(item("Bandeja de entrada", #selector(home), "1"))
        let edit = NSMenu(title: "Editar")
        edit.addItem(item("Deshacer", Selector(("undo:")), "z"))
        edit.addItem(item("Rehacer", Selector(("redo:")), "Z", [.command, .shift]))
        edit.addItem(.separator())
        edit.addItem(item("Cortar", #selector(NSText.cut(_:)), "x"))
        edit.addItem(item("Copiar", #selector(NSText.copy(_:)), "c"))
        edit.addItem(item("Pegar", #selector(NSText.paste(_:)), "v"))
        edit.addItem(item("Seleccionar todo", #selector(NSText.selectAll(_:)), "a"))
        let view = NSMenu(title: "Ver")
        view.addItem(item("Recargar", #selector(reload), "r"))
        view.addItem(item("Pantalla completa", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))
        let win = NSMenu(title: "Ventana")
        win.addItem(item("Minimizar", #selector(NSWindow.performMiniaturize(_:)), "m"))
        for (t, m) in [("Santoro Mail", app), ("Archivo", file), ("Editar", edit), ("Ver", view), ("Ventana", win)] {
            let top = NSMenuItem(title: t, action: nil, keyEquivalent: ""); top.submenu = m; main.addItem(top)
        }
        NSApp.mainMenu = main
        NSApp.windowsMenu = win
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
