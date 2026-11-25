import SwiftUI
import UserNotifications
#if os(macOS)
import AppKit
#endif

struct Alias: Identifiable, Hashable {
    var email: String
    var ident: String          // "santoro" | "hanif"
    var label: String
    var color: Color
    var main: Bool
    var source: String         // "ms" | "seen" | "manual"
    var id: String { email }
    var local: String { String(email.split(separator: "@").first ?? "") }
    var mark: String { main ? "HH" : String(label.prefix(1)).uppercased() }
}

struct Draft: Identifiable {
    var id = UUID()
    var from: String
    var to: String = ""
    var subject: String = ""
    var body: String = ""
    var replyTo: Mail? = nil
}

enum AppSection: Hashable { case mail, track, settings }

let FOLDERS: [(String, String, String)] = [
    ("inbox", "Bandeja de entrada", "tray"), ("sent", "Enviados", "paperplane"), ("drafts", "Borradores", "doc.text"),
    ("archive", "Archivo", "archivebox"), ("spam", "Spam", "xmark.shield"), ("trash", "Papelera", "trash")]

@MainActor
final class Store: ObservableObject {
    @Published var loggedIn = API.shared.token != nil
    @Published var me: Me?
    @Published var aliases: [Alias] = []
    @Published var box: [String: [Mail]] = [:]
    @Published var tracks: [Track] = []
    @Published var section: AppSection = .mail
    @Published var folder = "inbox"
    @Published var alias: String? = nil
    @Published var loading = false
    @Published var message: String?
    @Published var compose: Draft?
    @Published var aiOn = false
    @Published var details: [String: Detail] = [:]
    var prefs: [String: Any] = [:]
    private var knownInbox: Set<String> = []
    private var knownOpens: [String: Int] = [:]
    private var poller: Task<Void, Never>?

    // MARK: session
    func login() async {
        do {
            let t = try await Auth.shared.login()
            API.shared.token = t; loggedIn = true
            await start()
        } catch { message = "No se pudo entrar: \(error.localizedDescription)" }
    }
    func logout() {
        API.shared.token = nil; loggedIn = false; box = [:]; tracks = []; me = nil; poller?.cancel()
    }
    func start() async {
        guard loggedIn else { return }
        await refresh(first: true)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        poller?.cancel()
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await self?.refresh(first: false)
            }
        }
    }

    // MARK: loading
    func refresh(first: Bool = false) async {
        loading = true; defer { loading = false }
        do {
            let me = try await API.shared.get("/me", Me.self)
            self.me = me; aiOn = me.ai ?? false
            prefs = (try? await API.shared.json("/prefs")) ?? [:]
            async let inbox = API.shared.get("/messages?folder=inbox&top=120", [Mail].self)
            async let sent = try? API.shared.get("/messages?folder=sent&top=60", [Mail].self)
            async let drafts = try? API.shared.get("/messages?folder=drafts&top=30", [Mail].self)
            async let archive = try? API.shared.get("/messages?folder=archive&top=40", [Mail].self)
            async let spam = try? API.shared.get("/messages?folder=spam&top=30", [Mail].self)
            async let trash = try? API.shared.get("/messages?folder=trash&top=30", [Mail].self)
            async let trk = try? API.shared.get("/tracking", [Track].self)
            var b: [String: [Mail]] = [:]
            b["inbox"] = try await inbox
            b["sent"] = await sent ?? []; b["drafts"] = await drafts ?? []; b["archive"] = await archive ?? []
            b["spam"] = await spam ?? []; b["trash"] = await trash ?? []
            let t = await trk ?? []
            buildAliases(me: me, mails: b)
            notifyNew(inbox: b["inbox"] ?? [], tracks: t, first: first)
            box = b; tracks = t
            badge()
        } catch APIError.login {
            logout()
        } catch {
            if first { message = error.localizedDescription }
        }
    }

    /// Real aliases only: Microsoft (= created in GoDaddy) + addresses that receive mail + ones added by hand on the web.
    func buildAliases(me: Me, mails: [String: [Mail]]) {
        let dom = me.email.split(separator: "@").last.map(String.init) ?? "hanifhawlader.com"
        let saved = (prefs["aliases"] as? [[String: Any]]) ?? []
        var list: [String] = [me.email]
        list += (me.aliases ?? []).filter { $0.hasSuffix("@" + dom) }
        var seen: Set<String> = []
        for f in ["inbox", "archive", "spam", "trash"] {
            for m in mails[f] ?? [] { for a in m.to + (m.cc ?? []) where a.hasSuffix("@" + dom) { seen.insert(a) } }
        }
        list += seen.sorted()
        list += saved.filter { ($0["manual"] as? Bool) == true }.compactMap { $0["email"] as? String }
        var out: [Alias] = []
        for (i, e) in list.enumerated() where !out.contains(where: { $0.email == e }) {
            let s = saved.first { ($0["email"] as? String) == e } ?? [:]
            let local = String(e.split(separator: "@").first ?? "")
            let hex = (s["col"] as? String) ?? Brand.defaultColor[local] ?? Brand.palette[(i + 3) % Brand.palette.count]
            let main = e == me.email
            out.append(Alias(email: e, ident: main ? "hanif" : ((s["id"] as? String) ?? "santoro"),
                             label: (s["lbl"] as? String) ?? local.capitalized, color: Color(hex: hex), main: main,
                             source: main || (me.aliases ?? []).contains(e) ? "ms" : seen.contains(e) ? "seen" : "manual"))
        }
        aliases = out
    }

    // MARK: helpers for views
    func aliasFor(_ m: Mail) -> Alias? {
        let all = m.to + (m.cc ?? [])
        return aliases.first { all.contains($0.email) } ?? aliases.first { $0.main }
    }
    func color(_ m: Mail) -> Color { aliasFor(m)?.color ?? Brand.wine }
    var current: [Mail] {
        var l = box[folder] ?? []
        if let a = alias { l = l.filter { ($0.to + ($0.cc ?? [])).contains(a) || $0.from.e == a } }
        return l
    }
    func unread(_ a: String? = nil) -> Int {
        (box["inbox"] ?? []).filter { $0.unread && (a == nil || ($0.to + ($0.cc ?? [])).contains(a!)) }.count
    }
    var title: String {
        if section == .track { return "Seguimiento" }
        if section == .settings { return "Ajustes" }
        if let a = alias { return a.split(separator: "@").first.map { "\($0)@" } ?? a }
        return FOLDERS.first { $0.0 == folder }?.1 ?? "Correo"
    }
    func find(_ id: String) -> Mail? { for (_, l) in box { if let m = l.first(where: { $0.id == id }) { return m } }; return nil }
    func trackFor(_ m: Mail) -> Track? {
        tracks.first { $0.sub == m.sub && m.to.first == $0.to.e }
    }
    var waiting: Int { tracks.filter { $0.wait == true && $0.replied != true }.count }

    private func update(_ id: String, _ f: (inout Mail) -> Void) {
        for k in box.keys { if let i = box[k]?.firstIndex(where: { $0.id == id }) { f(&box[k]![i]) } }
    }

    // MARK: actions
    func setRead(_ m: Mail, _ read: Bool) async {
        update(m.id) { $0.unread = !read }; badge()
        try? await API.shared.req("/message/\(API.enc(m.id))", method: "PATCH", body: ["read": read])
    }
    func markAllRead() async {
        let l = current.filter { $0.unread }
        for m in l { update(m.id) { $0.unread = false } }; badge()
        for m in l { try? await API.shared.req("/message/\(API.enc(m.id))", method: "PATCH", body: ["read": true]) }
    }
    func toggleStar(_ m: Mail) async {
        update(m.id) { $0.star.toggle() }
        try? await API.shared.req("/message/\(API.enc(m.id))", method: "PATCH", body: ["star": !m.star])
    }
    func move(_ m: Mail, to dest: String) async {
        for k in box.keys { box[k]?.removeAll { $0.id == m.id } }
        badge()
        do { try await API.shared.req("/message/\(API.enc(m.id))/move", method: "POST", body: ["folder": dest]) }
        catch { message = error.localizedDescription }
        await refresh()
    }
    func detail(_ m: Mail) async -> Detail? {
        if let d = details[m.id] { return d }
        let d = try? await API.shared.get("/message/\(API.enc(m.id))", Detail.self)
        if let d { details[m.id] = d }
        return d
    }

    func composeNew(to: String = "", subject: String = "", body: String = "", reply: Mail? = nil) {
        let from: String = {
            if let r = reply, let a = aliasFor(r) { return a.email }
            if let a = alias { return a }
            return aliases.first { $0.ident == "santoro" && !$0.main }?.email ?? me?.email ?? ""
        }()
        compose = Draft(from: from, to: to, subject: subject, body: body, replyTo: reply)
    }

    func send(_ d: Draft, track: Bool, highlight: Bool) async throws {
        var text = d.body
        if highlight && aiOn && !text.contains("**") && !text.contains("==") {
            if let h = try? await AIPrompts.highlight(text) { text = h }
        }
        let name = d.replyTo?.from.n ?? String(d.to.split(separator: "@").first ?? "")
        _ = try await API.shared.req("/send", method: "POST", body: [
            "from": d.from, "to": d.to.trimmingCharacters(in: .whitespaces), "name": name,
            "subject": d.subject.isEmpty ? "(sin asunto)" : d.subject, "text": text, "sigAuto": true,
            "track": ["open": track, "click": track], "follow": 0])
        await refresh()
    }

    // MARK: notifications + badge
    private func notifyNew(inbox: [Mail], tracks t: [Track], first: Bool) {
        let ids = Set(inbox.map(\.id))
        if !first {
            for m in inbox where m.unread && !knownInbox.contains(m.id) { post(m.from.n, m.sub) }
            for r in t {
                let n = r.realOpens.count
                if let old = knownOpens[r.id], n > old { post("\(r.to.n) ha abierto tu correo", r.sub) }
            }
        }
        knownInbox = ids
        for r in t { knownOpens[r.id] = r.realOpens.count }
    }
    private func post(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
    func badge() {
        let n = unread()
        #if os(iOS)
        UNUserNotificationCenter.current().setBadgeCount(n)
        #else
        NSApplication.shared.dockTile.badgeLabel = n > 0 ? "\(n)" : nil
        #endif
    }
}

// MARK: AI prompts (same voice as the web app)
enum AIPrompts {
    static let brand = "Escribes para Hanif Hawlader, fundador de Santoro (marca de ropa de lujo de Santander, España). Estilo: elegante, breve, cálido, sin emojis, sin exageraciones."
    static let fmt = "Marca con **negrita** las palabras clave (fechas, horas, precios, cantidades, plazos, lo que hay que hacer) y con ==dobles iguales== lo más importante (máximo 2). No uses otro formato."

    static func strip(_ s: String) -> String { s.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "==", with: "") }
    static func norm(_ s: String) -> String { strip(s).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }

    static func highlight(_ text: String) async throws -> String? {
        let r = try await API.shared.ai("Devuelve EXACTAMENTE el mismo texto, sin cambiar, añadir ni quitar ninguna letra ni salto de línea. Solo rodea con ** entre 3 y 8 palabras o frases clave (fechas, horas, precios, cantidades, plazos, nombres de producto, lo que hay que hacer) y con == la frase más importante (máximo 2). Devuelve solo el texto.\n\n\(text)")
        return norm(r) == norm(text) ? r : nil
    }
    static func reply(to m: Mail, body: String, idea: String) async throws -> String {
        try await API.shared.ai("\(brand)\nEscribe la respuesta de Hanif a este correo, en el mismo idioma del correo. \(idea.isEmpty ? "" : "Lo que quiere decir: \(idea).") Firma solo \"Hanif\". \(fmt) Devuelve solo el cuerpo.\n\nDe: \(m.from.n)\nAsunto: \(m.sub)\n\n\(body.prefix(4000))")
    }
    static func write(idea: String, to: String) async throws -> (String?, String) {
        let r = try await API.shared.ai("\(brand)\nEscribe un correo en español de España a partir de esta idea: \"\(idea)\". Destinatario: \(to.isEmpty ? "—" : to). Firma solo \"Hanif\". \(fmt) Devuelve primero una línea \"Asunto: ...\" y luego el cuerpo.")
        var lines = r.components(separatedBy: "\n")
        if let f = lines.first, f.lowercased().hasPrefix("asunto:") {
            lines.removeFirst()
            return (String(f.dropFirst(7)).trimmingCharacters(in: .whitespaces), lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return (nil, r)
    }
    static func summary(_ mails: [Mail]) async throws -> String {
        let l = mails.prefix(25).map { "- \($0.from.n): \($0.sub) — \($0.snip.prefix(160))" }.joined(separator: "\n")
        return try await API.shared.ai("\(brand)\nEres el asistente de correo de Hanif. En español, resume el día en máximo 4 líneas cortas: lo más importante, a quién responder primero y por qué.\n\nCorreos:\n\(l)")
    }
}

/// **bold** and ==wine== → AttributedString for previews
func markup(_ s: String) -> AttributedString {
    var out = AttributedString()
    var rest = Substring(s)
    while !rest.isEmpty {
        let b = rest.range(of: "**"), w = rest.range(of: "==")
        guard let first = [b, w].compactMap({ $0 }).min(by: { $0.lowerBound < $1.lowerBound }) else { out += AttributedString(String(rest)); break }
        out += AttributedString(String(rest[..<first.lowerBound]))
        let tok = String(rest[first]); let after = rest[first.upperBound...]
        if let end = after.range(of: tok) {
            var part = AttributedString(String(after[..<end.lowerBound]))
            part.font = Brand.f(15, .semibold)
            if tok == "==" { part.foregroundColor = Brand.at }
            out += part; rest = after[end.upperBound...]
        } else { out += AttributedString(tok); rest = after }
    }
    return out
}
