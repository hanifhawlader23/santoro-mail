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

struct OutAtt: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var type: String
    var data: String          // base64
    var size: Int
}

struct Draft: Identifiable {
    var id = UUID()
    var from: String
    var to: String = ""
    var subject: String = ""
    var body: String = ""
    var replyTo: Mail? = nil
    var atts: [OutAtt] = []
    var sendAt: Date? = nil
}

struct DigestLine: Identifiable { var id = UUID(); var icon: String; var text: String }

/// Ajustes guardados en el teléfono / Mac
enum Pref {
    static var d: UserDefaults { .standard }
    static func bool(_ k: String, _ def: Bool = true) -> Bool { d.object(forKey: k) == nil ? def : d.bool(forKey: k) }
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
    @Published var activity: String? = nil        // logo animado arriba: Sincronizando… / Enviando… / Enviado
    @Published var booted = false                 // primera carga hecha (antes se ve la pantalla de inicio)
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
        API.shared.token = nil; loggedIn = false; box = [:]; tracks = []; me = nil; poller?.cancel(); booted = false
    }
    func start() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-preview") { loadPreview(); return }
        #endif
        guard loggedIn else { return }
        await refresh(first: true)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        poller?.cancel()
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await self?.refresh(first: false, quiet: true)
            }
        }
    }

    // MARK: loading
    func refresh(first: Bool = false, quiet: Bool = false) async {
        loading = true
        if !quiet { activity = "Sincronizando…" }
        defer { loading = false; booted = true; if activity == "Sincronizando…" { activity = nil } }
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
            if let d = UserDefaults.standard.string(forKey: "set.defaultFrom"), aliases.contains(where: { $0.email == d }) { return d }
            return aliases.first { $0.ident == "santoro" && !$0.main }?.email ?? me?.email ?? ""
        }()
        compose = Draft(from: from, to: to, subject: subject, body: body, replyTo: reply)
    }

    func send(_ d: Draft, track: Bool, highlight: Bool) async throws {
        let later = d.sendAt != nil
        activity = later ? "Programando…" : "Enviando…"
        do {
            var text = d.body
            if highlight && aiOn && !text.contains("**") && !text.contains("==") {
                if let h = try? await AIPrompts.highlight(text) { text = h }
            }
            let name = d.replyTo?.from.n ?? String(d.to.split(separator: "@").first ?? "")
            var body: [String: Any] = [
                "from": d.from, "to": d.to.trimmingCharacters(in: CharacterSet(charactersIn: " ,")), "name": name,
                "subject": d.subject.isEmpty ? "(sin asunto)" : d.subject, "text": text, "sigAuto": true,
                "track": ["open": track, "click": track], "follow": 0]
            if !d.atts.isEmpty { body["attachments"] = d.atts.map { ["name": $0.name, "type": $0.type, "data": $0.data] } }
            if let at = d.sendAt {
                body["at"] = ISO.b.string(from: at)
                try await API.shared.req("/sched", method: "POST", body: body)
            } else {
                try await API.shared.req("/send", method: "POST", body: body)
            }
        } catch { activity = nil; throw error }
        activity = later ? "Programado" : "Enviado"
        Task { try? await Task.sleep(nanoseconds: 1_400_000_000); if activity == "Enviado" || activity == "Programado" { activity = nil } }
        await refresh(quiet: true)
    }

    func saveDraft(_ d: Draft) async {
        activity = "Guardando…"
        try? await API.shared.req("/draft", method: "POST", body: ["from": d.from, "to": d.to, "subject": d.subject, "text": d.body])
        activity = "Borrador guardado"
        try? await Task.sleep(nanoseconds: 1_200_000_000); activity = nil
        await refresh(quiet: true)
    }

    func emptyTrash() async {
        activity = "Vaciando papelera…"
        try? await API.shared.req("/emptytrash", method: "POST")
        activity = nil
        await refresh()
    }

    // MARK: prefs compartidas con la web (plantillas, firmas…)
    var templates: [[String: Any]] { (prefs["templates"] as? [[String: Any]]) ?? [] }
    func saveTemplates(_ t: [[String: Any]]) async {
        prefs["templates"] = t
        try? await API.shared.req("/prefs", method: "PUT", body: prefs)
        objectWillChange.send()
    }

    // MARK: contactos (para sugerir al escribir «Para»)
    func isMine(_ e: String) -> Bool {
        let l = e.lowercased()
        return aliases.contains { $0.email.lowercased() == l } || l.hasSuffix("@hanifhawlader.com")
    }
    var contacts: [Addr] {
        var score: [String: (Addr, Int)] = [:]
        func add(_ a: Addr, _ w: Int) {
            let e = a.e.lowercased()
            guard e.contains("@"), !isMine(e), !e.contains("noreply"), !e.contains("no-reply") else { return }
            let name = a.n.isEmpty || a.n.contains("@") ? (score[e]?.0.n ?? a.n) : a.n
            score[e] = (Addr(n: name, e: e), (score[e]?.1 ?? 0) + w)
        }
        for m in box["inbox"] ?? [] { add(m.from, 1) }
        for m in box["archive"] ?? [] { add(m.from, 1) }
        for m in box["sent"] ?? [] { for t in m.to { add(Addr(n: String(t.split(separator: "@").first ?? ""), e: t), 3) } }
        for t in tracks { add(t.to, 3) }
        return score.values.sorted { $0.1 > $1.1 }.map(\.0)
    }
    func suggest(_ q: String) -> [Addr] {
        let k = q.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
        let all = contacts
        if k.isEmpty { return Array(all.prefix(5)) }
        return Array(all.filter { $0.e.hasPrefix(k) || $0.n.lowercased().split(separator: " ").contains { $0.hasPrefix(k) } || $0.e.contains(k) }.prefix(6))
    }

    // MARK: resumen del día (sin IA: solo datos reales, nunca inventa)
    var starred: Int { (box["inbox"] ?? []).filter(\.star).count }
    var digest: [DigestLine] {
        let un = (box["inbox"] ?? []).filter(\.unread).sorted { $0.when > $1.when }
        var out: [DigestLine] = []
        if un.isEmpty {
            out.append(.init(icon: "checkmark.seal", text: "Todo leído. Tu bandeja está al día."))
        } else {
            let per = aliases.filter { !$0.main }.compactMap { a -> String? in let n = unread(a.email); return n > 0 ? "\(n) en **\(a.local)@**" : nil }
            out.append(.init(icon: "tray.full", text: "**\(un.count) sin leer**" + (per.isEmpty ? "" : " · " + per.prefix(3).joined(separator: " · "))))
            for m in un.prefix(3) { out.append(.init(icon: "person.crop.circle", text: "**\(m.from.n)** — \(m.sub)")) }
            let pri = un.filter { $0.pri == true }.count
            if pri > 0 { out.append(.init(icon: "exclamationmark.circle", text: "==\(pri) marcado\(pri == 1 ? "" : "s") como importante\(pri == 1 ? "" : "s")==")) }
            let att = un.filter(\.att).count
            if att > 0 { out.append(.init(icon: "paperclip", text: "\(att) con archivos adjuntos")) }
        }
        let cal = Calendar.current
        let opened = tracks.filter { $0.realOpens.contains { cal.isDateInToday(ISO.parse($0.t)) } }
        if !opened.isEmpty { out.append(.init(icon: "eye", text: "**\(opened.count)** abri\(opened.count == 1 ? "ó" : "eron") tu correo hoy: " + opened.prefix(2).map(\.to.n).joined(separator: ", "))) }
        let old = tracks.filter { $0.wait == true && $0.replied != true && Date().timeIntervalSince(ISO.parse($0.date)) > 2 * 86400 }
        if !old.isEmpty { out.append(.init(icon: "clock.arrow.circlepath", text: "\(old.count) sin respuesta hace más de 2 días — " + old.prefix(2).map(\.to.n).joined(separator: ", "))) }
        return out
    }

    // MARK: notifications + badge
    private func notifyNew(inbox: [Mail], tracks t: [Track], first: Bool) {
        let ids = Set(inbox.map(\.id))
        if !first {
            if Pref.bool("set.notifNew") { for m in inbox where m.unread && !knownInbox.contains(m.id) { post(m.from.n, m.sub) } }
            if Pref.bool("set.notifOpen") {
                for r in t {
                    let n = r.realOpens.count
                    if let old = knownOpens[r.id], n > old { post("\(r.to.n) ha abierto tu correo", r.sub) }
                }
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
        let n = Pref.bool("set.badge") ? unread() : 0
        #if os(iOS)
        UNUserNotificationCenter.current().setBadgeCount(n)
        #else
        NSApplication.shared.dockTile.badgeLabel = n > 0 ? "\(n)" : nil
        #endif
    }
}

#if DEBUG
extension Store {
    /// Solo para el simulador (-preview): nunca entra en la app que instalas.
    func loadPreview() {
        loggedIn = true
        let me = Me(name: "Hanif Hawlader", email: "contacto@hanifhawlader.com", aliases: ["santoro@hanifhawlader.com", "pedidos@hanifhawlader.com", "club@hanifhawlader.com"], ai: true, aiPro: false)
        self.me = me; aiOn = true
        let now = Date()
        func iso(_ s: Double) -> String { ISO.b.string(from: now.addingTimeInterval(-s)) }
        let inbox: [Mail] = [
            Mail(id: "1", folder: "inbox", from: Addr(n: "Lanificio Ferla", e: "info@ferla.it"), to: ["santoro@hanifhawlader.com"], cc: nil, sub: "Muestras de lana fría", snip: "Hola Hanif, te enviamos las muestras el lunes…", date: iso(600), unread: true, star: false, att: true, pri: true),
            Mail(id: "2", folder: "inbox", from: Addr(n: "Marta Ruiz", e: "marta@gmail.com"), to: ["pedidos@hanifhawlader.com"], cc: nil, sub: "Camisa a medida para boda", snip: "Me caso en junio y quería una camisa…", date: iso(3600), unread: true, star: true, att: false, pri: nil),
            Mail(id: "3", folder: "inbox", from: Addr(n: "GoDaddy", e: "no-reply@godaddy.com"), to: ["contacto@hanifhawlader.com"], cc: nil, sub: "Tu dominio se renueva pronto", snip: "hanifhawlader.com se renovará…", date: iso(86400), unread: false, star: false, att: false, pri: nil)]
        box = ["inbox": inbox, "sent": [], "drafts": [], "archive": [], "spam": [], "trash": []]
        buildAliases(me: me, mails: box)
        activity = "Sincronizando…"
        Task { try? await Task.sleep(nanoseconds: 1_800_000_000); booted = true; try? await Task.sleep(nanoseconds: 1_500_000_000); activity = nil }
    }
}
#endif

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
func markup(_ s: String, size: CGFloat = 15) -> AttributedString {
    var out = AttributedString()
    var rest = Substring(s)
    while !rest.isEmpty {
        let b = rest.range(of: "**"), w = rest.range(of: "==")
        guard let first = [b, w].compactMap({ $0 }).min(by: { $0.lowerBound < $1.lowerBound }) else { out += AttributedString(String(rest)); break }
        out += AttributedString(String(rest[..<first.lowerBound]))
        let tok = String(rest[first]); let after = rest[first.upperBound...]
        if let end = after.range(of: tok) {
            var part = AttributedString(String(after[..<end.lowerBound]))
            part.font = Brand.f(size, .semibold)
            if tok == "==" { part.foregroundColor = Brand.at }
            out += part; rest = after[end.upperBound...]
        } else { out += AttributedString(tok); rest = after }
    }
    return out
}
