import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct MainView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hsize
    var body: some View {
        if hsize == .compact { PhoneMain() } else { WideMain() }
    }
    #else
    var body: some View { WideMain() }
    #endif
}

/// Mac e iPad: tres columnas
struct WideMain: View {
    @EnvironmentObject var s: Store
    @State private var sel: String?
    @State private var column: NavigationSplitViewColumn = .content
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $column) {
            Sidebar(column: $column)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } content: {
            Group {
                switch s.section {
                case .mail: MailList(sel: $sel)
                case .track: TrackList()
                case .settings: SettingsView()
                }
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 400, max: 520)
        } detail: {
            if s.section == .mail, let id = sel, let m = s.find(id) {
                Reader(mail: m).id(id)
            } else {
                VStack(spacing: 12) {
                    Image("RiderWine").resizable().scaledToFit().frame(width: 90).opacity(0.25)
                    Text("Elige un correo").font(Brand.f(14)).foregroundStyle(Brand.fg3)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Brand.bg)
            }
        }
        .overlay(alignment: .top) { SyncPill() }
        .sheet(item: $s.compose) { d in ComposeView(draft: d).environmentObject(s) }
        .onChange(of: s.folder) { _, _ in sel = nil }
        .onChange(of: s.alias) { _, _ in sel = nil }
    }
}

// MARK: sidebar — accounts, aliases, folders
struct Sidebar: View {
    @EnvironmentObject var s: Store
    @Binding var column: NavigationSplitViewColumn
    var body: some View {
        List {
            HStack(spacing: 12) {
                SantoroAvatar(size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SANTORO").font(Brand.f(15, .medium)).tracking(4).foregroundStyle(Brand.at)
                    Text("Hanif Hawlader · Mail").font(Brand.f(11)).foregroundStyle(Brand.fg3)
                }
            }
            .listRowSeparator(.hidden).padding(.vertical, 6)

            Button { s.composeNew() } label: {
                Label("Redactar", systemImage: "square.and.pencil").font(Brand.f(15, .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .foregroundStyle(Brand.cream).background(RoundedRectangle(cornerRadius: 10).fill(Brand.wine))
            }
            .buttonStyle(.plain).listRowSeparator(.hidden)

            Section {
                row(icon: AnyView(Image(systemName: "tray.2").foregroundStyle(Brand.at)), title: "Todas", n: s.unread(), on: s.section == .mail && s.folder == "inbox" && s.alias == nil) {
                    s.section = .mail; s.folder = "inbox"; s.alias = nil
                }
                ForEach(s.aliases) { a in
                    row(icon: AnyView(Text(a.mark).font(Brand.f(10, .medium)).foregroundStyle(.white).frame(width: 24, height: 20).background(RoundedRectangle(cornerRadius: 5).fill(a.color))),
                        title: a.local + "@", n: s.unread(a.email), on: s.section == .mail && s.alias == a.email) {
                        s.section = .mail; s.folder = "inbox"; s.alias = a.email
                    }
                }
            } header: { Cap("Bandejas") }

            Section {
                ForEach(FOLDERS.dropFirst(), id: \.0) { f in
                    row(icon: AnyView(Image(systemName: f.2).foregroundStyle(Brand.fg2)), title: f.1, n: f.0 == "drafts" ? (s.box["drafts"]?.count ?? 0) : 0,
                        on: s.section == .mail && s.folder == f.0 && s.alias == nil) {
                        s.section = .mail; s.folder = f.0; s.alias = nil
                    }
                }
            } header: { Cap("Carpetas") }

            Section {
                row(icon: AnyView(Image(systemName: "eye").foregroundStyle(Brand.fg2)), title: "Seguimiento", n: s.waiting, on: s.section == .track) { s.section = .track }
                row(icon: AnyView(Image(systemName: "gearshape").foregroundStyle(Brand.fg2)), title: "Ajustes", n: 0, on: s.section == .settings) { s.section = .settings }
            } header: { Cap("Herramientas") }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Brand.bg)
        .navigationTitle("Santoro")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    func row(icon: AnyView, title: String, n: Int, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action(); column = .content
        } label: {
            HStack(spacing: 10) {
                icon.frame(width: 26)
                Text(title).font(Brand.f(15, on ? .medium : .regular)).foregroundStyle(Brand.fg)
                Spacer()
                if n > 0 { Text("\(n)").font(Brand.f(12, .medium)).foregroundStyle(Brand.at) }
            }
            .padding(.vertical, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(on ? Brand.wine.opacity(0.10) : Color.clear)
    }
}

// MARK: list
struct MailList: View {
    @EnvironmentObject var s: Store
    @Binding var sel: String?
    @State private var q = ""
    @State private var showDigest = false
    @State private var pull: CGFloat = 0
    @State private var ask: (Mail, String)? = nil     // se confirma antes de hacer nada
    @AppStorage("set.confirmSwipe") private var confirmSwipe = true

    var rows: [Mail] {
        let l = s.current
        guard !q.isEmpty else { return l }
        let k = q.lowercased()
        return l.filter { ($0.from.n + $0.from.e + $0.sub + $0.snip).lowercased().contains(k) }
    }

    var body: some View {
        List(selection: $sel) {
            if s.folder == "inbox" && q.isEmpty {
                if s.alias == nil { greeting.listRowSeparator(.hidden).listRowBackground(Color.clear) }
                chips.listRowSeparator(.hidden).listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 0))
            }
            if rows.isEmpty && !s.loading {
                VStack(spacing: 10) {
                    Image("RiderWine").resizable().scaledToFit().frame(width: 70).opacity(0.25)
                    Text("Nada por aquí").font(Brand.f(13)).foregroundStyle(Brand.fg3)
                }.frame(maxWidth: .infinity).padding(.top, 50).listRowSeparator(.hidden).listRowBackground(Color.clear)
            }
            ForEach(rows) { m in
                link(m)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12))
                    .listRowBackground(m.unread ? s.color(m).opacity(0.08) : Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {      // ← responder · reenviar · borrar
                        Button { act(m, "del") } label: { Label("Eliminar", systemImage: "trash") }.tint(Color(red: 0.56, green: 0.17, blue: 0.17))
                        Button { s.composeNew(subject: "Fwd: " + m.sub, body: "\n\n---------- Reenviado ----------\nDe: \(m.from.n) <\(m.from.e)>\nAsunto: \(m.sub)\n\n" + m.snip) } label: { Label("Reenviar", systemImage: "arrowshape.turn.up.right") }.tint(Color(red: 0.34, green: 0.38, blue: 0.18))
                        Button { s.composeNew(reply: m) } label: { Label("Responder", systemImage: "arrowshape.turn.up.left") }.tint(Color(red: 0.18, green: 0.42, blue: 0.40))
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {       // → me encanta · destacar · leído
                        Button { act(m, "star") } label: { Label(m.star ? "Quitar" : "Destacar", systemImage: m.star ? "star.slash" : "star") }.tint(Color(red: 0.55, green: 0.42, blue: 0.26))
                        Button { act(m, "read") } label: { Label(m.unread ? "Leído" : "No leído", systemImage: m.unread ? "envelope.open" : "envelope.badge") }.tint(Color(red: 0.14, green: 0.28, blue: 0.42))
                    }
                    .contextMenu {
                        Button(m.unread ? "Marcar como leído" : "Marcar como no leído") { Task { await s.setRead(m, m.unread) } }
                        Button(m.star ? "Quitar destacado" : "Destacar") { Task { await s.toggleStar(m) } }
                        Button("Responder") { s.composeNew(to: m.from.e, subject: "Re: " + m.sub, reply: m) }
                        Divider()
                        Button("Spam") { Task { await s.move(m, to: "spam") } }
                        Button("Eliminar", role: .destructive) { Task { await s.move(m, to: "trash") } }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Brand.bg)
        .searchable(text: $q, prompt: "Buscar correos, personas, pedidos…")
        .refreshable { await s.refresh() }
        #if os(iOS)
        .modifier(PullTracker(pull: $pull))
        .overlay(alignment: .top) { PullLogo(pull: pull, busy: s.loading && s.activity == "Sincronizando…") }
        #endif
        .confirmationDialog(ask?.1 == "del" ? "¿Eliminar este correo?" : "¿Seguro?", isPresented: Binding(get: { ask != nil }, set: { if !$0 { ask = nil } }), titleVisibility: .visible) {
            if let a = ask {
                Button(a.1 == "del" ? "Eliminar" : a.1 == "star" ? (a.0.star ? "Quitar destacado" : "Destacar") : (a.0.unread ? "Marcar como leído" : "Marcar como no leído"), role: a.1 == "del" ? .destructive : nil) {
                    run(a.0, a.1); ask = nil
                }
            }
            Button("Cancelar", role: .cancel) { ask = nil }
        }
        .navigationTitle(s.title)
        .toolbar {
            ToolbarItemGroup {
                if s.loading { ProgressView().controlSize(.small) }
                if s.current.contains(where: { $0.unread }) {
                    Button { Task { await s.markAllRead() } } label: { Image(systemName: "checkmark.circle") }.help("Marcar todo como leído")
                }
                #if os(macOS)
                Button { Task { await s.refresh() } } label: { Image(systemName: "arrow.clockwise") }.help("Actualizar")
                Button { s.composeNew() } label: { Image(systemName: "square.and.pencil") }.help("Nuevo correo")
                #endif
            }
        }
    }

    func link(_ m: Mail) -> some View {
        // al tocar, la lista marca la selección y PhoneMain/WideMain abren el correo
        MailRow(m: m, alias: s.aliasFor(m), sent: s.folder == "sent" || s.folder == "drafts", track: s.folder == "sent" ? s.trackFor(m) : nil)
            .contentShape(Rectangle())
            .tag(m.id)
    }
    func act(_ m: Mail, _ k: String) { if confirmSwipe { ask = (m, k) } else { run(m, k) } }
    func run(_ m: Mail, _ k: String) {
        Task { if k == "del" { await s.move(m, to: "trash") } else if k == "star" { await s.toggleStar(m) } else { await s.setRead(m, m.unread) } }
    }

    /// Resumen: fecha, hora, lo que queda del mes y los números del día — compacto
    var greeting: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tl in
            let d = tl.date
            let es = Locale(identifier: "es_ES")
            let cal = Calendar.current
            let h = cal.component(.hour, from: d)
            let g = h < 6 ? "Buenas noches" : h < 14 ? "Buenos días" : h < 21 ? "Buenas tardes" : "Buenas noches"
            let left = (cal.range(of: .day, in: .month, for: d)?.count ?? 30) - cal.component(.day, from: d)
            let month = d.formatted(Date.FormatStyle(locale: es).month(.wide))
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .center, spacing: 11) {
                    SantoroAvatar(size: 44, who: "hanif")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(g), Hanif").font(Brand.f(18, .medium)).foregroundStyle(Brand.fg).lineLimit(1).minimumScaleFactor(0.8)
                        Text(day(d, es)).font(Brand.f(12.5)).foregroundStyle(Brand.fg3).lineLimit(1)
                        Text(left == 0 ? "Último día de \(month)" : "Quedan \(left) días de \(month)").font(Brand.f(11)).foregroundStyle(Brand.at.opacity(0.85))
                    }
                    Spacer(minLength: 4)
                    Text(d.formatted(Date.FormatStyle(locale: es).hour(.twoDigits(amPM: .omitted)).minute()))
                        .font(Brand.f(17, .medium)).foregroundStyle(Brand.cream).monospacedDigit()
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Brand.wine))
                }
                HStack(spacing: 6) {
                    stat("envelope.badge", s.unread(), "sin leer")
                    stat("clock", s.waiting, "esperando")
                    stat("star", s.starred, "destacados")
                }
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showDigest.toggle() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.badge.star")
                        Text(showDigest ? "Ocultar resumen" : "Resumen del día").font(Brand.f(13, .medium))
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(showDigest ? 180 : 0)).font(.caption.weight(.semibold))
                    }.foregroundStyle(Brand.at).contentShape(Rectangle())
                }.buttonStyle(.plain)
                if showDigest {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(s.digest) { l in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: l.icon).font(.system(size: 12)).foregroundStyle(Brand.at).frame(width: 16)
                                Text(markup(l.text, size: 13)).font(Brand.f(13)).foregroundStyle(Brand.fg2).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Brand.wine.opacity(0.05)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line, lineWidth: 1))
        .padding(.vertical, 4)
    }
    func day(_ d: Date, _ es: Locale) -> String {
        let t = d.formatted(Date.FormatStyle(locale: es).weekday(.wide).day().month(.wide))
        return t.prefix(1).uppercased() + t.dropFirst()
    }
    func stat(_ icon: String, _ n: Int, _ l: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(n > 0 ? Brand.at : Brand.fg3)
            Text("\(n)").font(Brand.f(14, .semibold)).foregroundStyle(n > 0 ? Brand.fg : Brand.fg3)
            Text(l).font(Brand.f(11)).foregroundStyle(Brand.fg3).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9).padding(.vertical, 6).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Brand.bg))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line, lineWidth: 1))
    }

    var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(title: "Todo", color: Brand.wine, n: s.unread(), on: s.alias == nil) { s.alias = nil }
                ForEach(s.aliases) { a in chip(title: a.local, color: a.color, n: s.unread(a.email), on: s.alias == a.email) { s.alias = a.email } }
            }.padding(.trailing, 12)
        }
    }
    func chip(title: String, color: Color, n: Int, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(on ? Color.white : color).frame(width: 8, height: 8)
                Text(title).font(Brand.f(13))
                if n > 0 { Text("\(n)").font(Brand.f(11, .semibold)) }
            }
            .foregroundStyle(on ? Color.white : Brand.fg2)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(on ? color : Color.clear))
            .overlay(Capsule().stroke(on ? color : Brand.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

struct MailRow: View {
    let m: Mail
    let alias: Alias?
    var sent = false
    var track: Track? = nil
    var body: some View {
        let c = alias?.color ?? Brand.wine
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(c).frame(width: m.unread ? 5 : 3).opacity(m.unread ? 1 : 0.45)
            Initials(name: sent ? (m.to.first ?? "?") : m.from.n, color: c, size: 40, ring: m.unread, email: sent ? nil : m.from.e).padding(.top, 12)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if m.unread { Circle().fill(c).frame(width: 7, height: 7) }
                    Text(sent ? "Para: " + (m.to.first ?? "—") : m.from.n)
                        .font(Brand.f(15, m.unread ? .semibold : .regular)).foregroundStyle(m.unread ? Brand.fg : Brand.fg2).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(relTime(m.when)).font(Brand.f(12, m.unread ? .semibold : .regular)).foregroundStyle(m.unread ? c : Brand.fg3)
                }
                Text(m.sub).font(Brand.f(14, m.unread ? .semibold : .regular)).foregroundStyle(m.unread ? Brand.fg : Brand.fg2).lineLimit(1)
                Text(AIPrompts.strip(m.snip).replacingOccurrences(of: "\n", with: " "))
                    .font(Brand.f(13)).foregroundStyle(Brand.fg3).lineLimit(2)
                HStack(spacing: 8) {
                    if let a = alias { Text(a.mark).font(Brand.f(9.5, .medium)).tracking(1).foregroundStyle(c).padding(.horizontal, 5).padding(.vertical, 1).overlay(RoundedRectangle(cornerRadius: 3).stroke(c.opacity(0.5))) }
                    if m.att { Image(systemName: "paperclip").font(.caption).foregroundStyle(Brand.fg3) }
                    if m.star { Image(systemName: "star.fill").font(.caption).foregroundStyle(Brand.at) }
                    if m.pri == true { Image(systemName: "exclamationmark").font(.caption.bold()).foregroundStyle(Brand.at) }
                    if let t = track {
                        let n = t.realOpens.count
                        Label(n > 0 ? "Abierto \(n)×" : "Sin abrir", systemImage: n > 0 ? "eye.fill" : "eye.slash")
                            .font(Brand.f(11, .medium)).foregroundStyle(n > 0 ? Brand.at : Brand.fg3)
                    }
                }.padding(.top, 2)
            }
            .padding(.vertical, 11)
        }
    }
}

// MARK: reader
struct Reader: View {
    @EnvironmentObject var s: Store
    let mail: Mail
    @State private var detail: Detail?
    @State private var aiBusy = false
    var body: some View {
        let a = s.aliasFor(mail), c = a?.color ?? Brand.wine
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(c).frame(height: 4)
            VStack(alignment: .leading, spacing: 10) {
                Text(mail.sub).font(Brand.f(24, .medium)).foregroundStyle(Brand.fg).textSelection(.enabled)
                HStack(spacing: 12) {
                    Initials(name: mail.from.n, color: c, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(mail.from.n).font(Brand.f(15, .medium))
                        Text(mail.from.e).font(Brand.f(12)).foregroundStyle(Brand.fg3).textSelection(.enabled)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let a { Label(a.email, systemImage: "tray").font(Brand.f(11.5)).foregroundStyle(c).padding(.horizontal, 9).padding(.vertical, 3).overlay(Capsule().stroke(c.opacity(0.4))) }
                        Text(mail.when.formatted(date: .abbreviated, time: .shortened)).font(Brand.f(11.5)).foregroundStyle(Brand.fg3)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pill("Responder", "arrowshape.turn.up.left") { s.composeNew(to: mail.from.e, subject: re(mail.sub), reply: mail) }
                    if s.aiOn {
                        pill(aiBusy ? "Escribiendo…" : "Respuesta IA", "sparkles") {
                            aiBusy = true
                            Task {
                                let body = await plain()
                                let txt = (try? await AIPrompts.reply(to: mail, body: body, idea: "")) ?? ""
                                aiBusy = false
                                s.composeNew(to: mail.from.e, subject: re(mail.sub), body: txt, reply: mail)
                            }
                        }
                    }
                    pill("Reenviar", "arrowshape.turn.up.right") { s.composeNew(subject: "Fwd: " + mail.sub, body: "\n\n---------- Reenviado ----------\nDe: \(mail.from.n) <\(mail.from.e)>\nAsunto: \(mail.sub)\n\n" + mail.snip) }
                    pill("", "trash") { Task { await s.move(mail, to: "trash") } }
                    pill("", mail.star ? "star.fill" : "star") { Task { await s.toggleStar(mail) } }
                }
                }
                if let atts = detail?.atts, !atts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(atts) { at in Label(at.name, systemImage: "paperclip").font(Brand.f(12)).padding(.horizontal, 10).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 8).fill(Brand.card)) } }
                    }
                }
            }
            .padding(20)
            Divider()
            if let html = detail?.html {
                HTMLView(html: html).background(Color.white)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Brand.bg)
        .task {
            detail = await s.detail(mail)
            if mail.unread { await s.setRead(mail, true) }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    func re(_ s: String) -> String { s.lowercased().hasPrefix("re:") ? s : "Re: " + s }
    func plain() async -> String {
        let h = detail?.html ?? mail.snip
        return h.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    func pill(_ t: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) { Image(systemName: icon); if !t.isEmpty { Text(t).font(Brand.f(13, .medium)) } }
                .foregroundStyle(Brand.at).padding(.horizontal, 11).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(Brand.card))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Brand.line))
        }.buttonStyle(.plain)
    }
}

/// Mail body (HTML) — our own tracking pixel is removed so reading it never counts as an "open".
struct HTMLView {
    let html: String
    func doc() -> String {
        let clean = html.replacingOccurrences(of: "<img[^>]+/t/o/[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: "", options: .regularExpression)
        return "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'><style>body{margin:0;padding:18px;font-family:-apple-system,Georgia,serif;font-size:15px;line-height:1.6;color:#111;background:#fff;word-wrap:break-word}img{max-width:100%;height:auto}table{max-width:100%}a{color:#5B1A2C}</style></head><body>\(clean)</body></html>"
    }
    final class Coord: NSObject, WKNavigationDelegate {
        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler h: @escaping (WKNavigationActionPolicy) -> Void) {
            if a.navigationType == .linkActivated, let u = a.request.url {
                #if os(iOS)
                UIApplication.shared.open(u)
                #else
                NSWorkspace.shared.open(u)
                #endif
                return h(.cancel)
            }
            h(.allow)
        }
    }
    func makeCoordinator() -> Coord { Coord() }
    func make(_ c: Coord) -> WKWebView { let w = WKWebView(); w.navigationDelegate = c; w.loadHTMLString(doc(), baseURL: URL(string: BASE)); return w }
}
#if os(iOS)
extension HTMLView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { make(context.coordinator) }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
#else
extension HTMLView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { make(context.coordinator) }
    func updateNSView(_ v: WKWebView, context: Context) {}
}
#endif
