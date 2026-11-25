import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

// MARK: compose
struct ComposeView: View {
    @EnvironmentObject var s: Store
    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft
    @AppStorage("set.track") private var track = true
    @AppStorage("set.highlight") private var highlight = true
    @State private var idea = ""
    @State private var busy = false
    @State private var sending = false
    @State private var error: String?
    @State private var showAI = false
    @State private var pickFile = false
    @State private var photo: PhotosPickerItem?
    @State private var check: String?
    @State private var schedule = false
    @State private var closeAsk = false
    @FocusState private var focus: Field?
    enum Field { case to, subject, body, idea }

    var fromAlias: Alias? { s.aliases.first { $0.email == draft.from } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    fromChips
                    line("Para") {
                        TextField("nombre@empresa.com", text: $draft.to).font(Brand.f(16)).focused($focus, equals: .to)
                            #if os(iOS)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                            #endif
                    }
                    if focus == .to { suggestions }
                    line("Asunto") { TextField("", text: $draft.subject).font(Brand.f(16)).focused($focus, equals: .subject) }

                    tools.padding(.top, 12)

                    if showAI && s.aiOn { aiBox.padding(.top, 10).transition(.opacity.combined(with: .move(edge: .top))) }
                    if !draft.atts.isEmpty { attList.padding(.top, 10) }
                    if let at = draft.sendAt { schedBanner(at).padding(.top, 10) }

                    ZStack(alignment: .topLeading) {
                        if draft.body.isEmpty {
                            Text("Escribe tu mensaje…").font(Brand.f(16)).foregroundStyle(Brand.fg3).padding(.top, 14).padding(.leading, 5)
                        }
                        TextEditor(text: $draft.body)
                            .font(Brand.f(16)).frame(minHeight: 230).scrollContentBackground(.hidden)
                            .focused($focus, equals: .body)
                            .padding(.vertical, 6)
                    }
                    if draft.body.contains("**") || draft.body.contains("==") {
                        VStack(alignment: .leading, spacing: 6) {
                            Cap("Así se verá")
                            Text(markup(draft.body)).font(Brand.f(15)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Brand.card))
                    }
                    options.padding(.top, 14)
                    if let error { Text(error).font(Brand.f(13)).foregroundStyle(.red).padding(.top, 8) }
                }
                .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Brand.bg)
            .navigationTitle(draft.replyTo == nil ? "Nuevo correo" : "Responder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { if draft.body.isEmpty && draft.to.isEmpty { dismiss() } else { closeAsk = true } } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) { sendButton }
            }
            .confirmationDialog("¿Qué hacemos con este correo?", isPresented: $closeAsk, titleVisibility: .visible) {
                Button("Guardar en borradores") { let d = draft; dismiss(); Task { await s.saveDraft(d) } }
                Button("Descartar", role: .destructive) { dismiss() }
                Button("Seguir escribiendo", role: .cancel) {}
            }
            .alert("Antes de enviar", isPresented: Binding(get: { check != nil }, set: { if !$0 { check = nil } })) {
                Button("Revisar", role: .cancel) { check = nil }
                Button("Enviar igual") { check = nil; go(force: true) }
            } message: { Text(check ?? "") }
            .sheet(isPresented: $schedule) { ScheduleSheet(when: $draft.sendAt).presentationDetents([.medium, .large]) }
            .fileImporter(isPresented: $pickFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { r in
                if case .success(let urls) = r { for u in urls { addFile(u) } }
            }
            .onChange(of: photo) { _, p in
                guard let p else { return }
                Task {
                    if let d = try? await p.loadTransferable(type: Data.self) {
                        let n = draft.atts.filter { $0.name.hasPrefix("foto") }.count + 1
                        draft.atts.append(OutAtt(name: "foto-\(n).jpg", type: "image/jpeg", data: shrink(d).base64EncodedString(), size: d.count))
                    }
                    photo = nil
                }
            }
        }
        .tint(Brand.at)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 680)
        #endif
        .onAppear { focus = draft.to.isEmpty ? .to : .body }
    }

    // MARK: partes
    var fromChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Cap("Enviar como")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(s.aliases) { a in
                        let on = a.email == draft.from
                        Button { withAnimation(.easeOut(duration: 0.15)) { draft.from = a.email } } label: {
                            HStack(spacing: 7) {
                                Text(a.mark).font(Brand.f(9.5, .medium)).foregroundStyle(.white).frame(width: 22, height: 18)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(on ? Color.white.opacity(0.22) : a.color))
                                Text(a.local + "@").font(Brand.f(13.5, on ? .medium : .regular))
                            }
                            .foregroundStyle(on ? Color.white : Brand.fg2)
                            .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
                            .background(Capsule().fill(on ? a.color : Brand.card))
                            .overlay(Capsule().stroke(on ? a.color : Brand.line, lineWidth: 1))
                            .shadow(color: on ? a.color.opacity(0.3) : .clear, radius: 4, y: 2)
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 2)
            }
            Text("Firma: \(fromAlias?.ident == "hanif" ? "Hanif Hawlader" : "Santoro") · se añade sola").font(Brand.f(11.5)).foregroundStyle(Brand.fg3)
        }
        .padding(.bottom, 6)
    }

    var suggestions: some View {
        let l = s.suggest(draft.to)
        return VStack(spacing: 0) {
            ForEach(l, id: \.e) { c in
                Button {
                    var parts = draft.to.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    if let last = parts.last, !last.contains("@") || c.e.hasPrefix(last.lowercased()) { parts.removeLast() }
                    parts.append(c.e)
                    draft.to = parts.joined(separator: ", ")
                    focus = .subject
                } label: {
                    HStack(spacing: 10) {
                        Initials(name: c.n.isEmpty ? c.e : c.n, size: 30, email: c.e)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(c.n.isEmpty ? c.e : c.n).font(Brand.f(14, .medium)).foregroundStyle(Brand.fg).lineLimit(1)
                            Text(c.e).font(Brand.f(12)).foregroundStyle(Brand.fg3).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(Brand.at)
                    }
                    .padding(.vertical, 7).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Brand.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
        .padding(.vertical, 6)
    }

    var tools: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                tool("paperclip", "Adjuntar") { pickFile = true }
                PhotosPicker(selection: $photo, matching: .images) { toolFace("photo", "Foto") }.buttonStyle(.plain)
                if s.aiOn { tool("sparkles", "IA", on: showAI) { withAnimation(.spring(response: 0.3)) { showAI.toggle(); if showAI { focus = .idea } } } }
                tool("bold", "Negrita") { wrap("**") }
                tool("paintbrush.pointed", "Vino", wine: true) { wrap("==") }
                if s.aiOn {
                    tool("wand.and.stars", busy ? "…" : "Resaltar") {
                        busy = true
                        Task {
                            if let r = try? await AIPrompts.highlight(AIPrompts.strip(draft.body)) { draft.body = r } else { error = "La IA no pudo resaltar ahora." }
                            busy = false
                        }
                    }
                }
                if !s.templates.isEmpty {
                    Menu {
                        ForEach(Array(s.templates.enumerated()), id: \.offset) { _, t in
                            Button((t["name"] as? String) ?? "Plantilla") { useTemplate(t) }
                        }
                    } label: { toolFace("doc.on.doc", "Plantillas") }.buttonStyle(.plain)
                }
                tool("clock", draft.sendAt == nil ? "Programar" : "Hora", on: draft.sendAt != nil) { schedule = true }
            }.padding(.vertical, 3).padding(.horizontal, 1)
        }
    }

    var aiBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(Brand.at)
            TextField(draft.replyTo == nil ? "Dile a la IA qué quieres escribir…" : "¿Qué quieres responder? (opcional)", text: $idea, axis: .vertical)
                .font(Brand.f(14)).focused($focus, equals: .idea).onSubmit(runAI)
            Button(action: runAI) {
                if busy { ProgressView().controlSize(.small).tint(Brand.cream) } else { Text("Escribir").font(Brand.f(13, .medium)) }
            }
            .foregroundStyle(Brand.cream).padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Brand.wine)).buttonStyle(.plain).disabled(busy)
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Brand.wine.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.wine.opacity(0.15)))
    }

    var attList: some View {
        VStack(spacing: 6) {
            ForEach(draft.atts) { a in
                HStack(spacing: 10) {
                    Image(systemName: a.type.hasPrefix("image") ? "photo" : "doc").foregroundStyle(Brand.at).frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Brand.wine.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(a.name).font(Brand.f(13.5)).lineLimit(1)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(a.size), countStyle: .file)).font(Brand.f(11)).foregroundStyle(Brand.fg3)
                    }
                    Spacer()
                    Button { draft.atts.removeAll { $0.id == a.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.fg3) }.buttonStyle(.plain)
                }
                .padding(8).background(RoundedRectangle(cornerRadius: 11).fill(Brand.card))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Brand.line))
            }
        }
    }

    func schedBanner(_ at: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill").foregroundStyle(Brand.cream)
            Text("Se enviará el \(at.formatted(Date.FormatStyle(locale: Locale(identifier: "es_ES")).weekday(.wide).day().month().hour().minute()))")
                .font(Brand.f(13, .medium)).foregroundStyle(Brand.cream)
            Spacer()
            Button { draft.sendAt = nil } label: { Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(Brand.cream) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9).background(RoundedRectangle(cornerRadius: 11).fill(Brand.wine))
    }

    var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $highlight) { Label("La IA resalta lo importante al enviar", systemImage: "sparkles").font(Brand.f(14)) }.disabled(!s.aiOn)
            Toggle(isOn: $track) { Label("Saber si lo abre y si hace clic", systemImage: "eye").font(Brand.f(14)) }
        }
        .tint(Brand.wine).padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Brand.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    var sendButton: some View {
        Button { go() } label: {
            HStack(spacing: 6) {
                if sending { ProgressView().controlSize(.small).tint(Brand.cream) }
                else { Image(systemName: draft.sendAt == nil ? "paperplane.fill" : "clock.fill") }
                Text(draft.sendAt == nil ? "Enviar" : "Programar").font(Brand.f(14.5, .medium))
            }
            .foregroundStyle(Brand.cream).padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(draft.to.isEmpty ? Brand.wine.opacity(0.4) : Brand.wine))
        }
        .buttonStyle(.plain)
        .disabled(sending || draft.to.isEmpty)
    }

    func tool(_ icon: String, _ t: String, on: Bool = false, wine: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolFace(icon, t, on: on, wine: wine) }.buttonStyle(.plain)
    }
    func toolFace(_ icon: String, _ t: String, on: Bool = false, wine: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(t).font(Brand.f(13, .medium))
        }
        .foregroundStyle(on ? Brand.cream : (wine ? Brand.at : Brand.fg))
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(on ? AnyShapeStyle(Brand.wine) : AnyShapeStyle(Brand.card)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Brand.wine : Brand.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1.5)
    }
    func line<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) { Text(label).font(Brand.f(13)).foregroundStyle(Brand.fg3).frame(width: 52, alignment: .leading); c() }
                .padding(.vertical, 11)
            Divider()
        }
    }

    // MARK: acciones
    func go(force: Bool = false) {
        let to = draft.to.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let bad = to.filter { $0.range(of: "^[^@\\s]+@[^@\\s]+\\.[a-zA-Z]{2,}$", options: .regularExpression) == nil }
        if !bad.isEmpty { error = "Revisa la dirección: \(bad.joined(separator: ", "))"; return }
        if !force {
            let low = draft.body.lowercased() + " " + draft.subject.lowercased()
            if draft.atts.isEmpty && ["adjunto", "adjunta", "adjuntos", "te envío el archivo", "attached", "attachment"].contains(where: { low.contains($0) }) {
                check = "Dices que adjuntas algo, pero no hay ningún archivo."; return
            }
            if draft.subject.trimmingCharacters(in: .whitespaces).isEmpty { check = "El correo no tiene asunto."; return }
            if AIPrompts.strip(draft.body).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { check = "El mensaje está vacío."; return }
            if draft.atts.reduce(0, { $0 + $1.size }) > 3_000_000 { check = "Los adjuntos pesan más de 3 MB y puede que Microsoft no los acepte."; return }
        }
        sending = true; error = nil
        Task {
            do { try await s.send(draft, track: track, highlight: highlight); dismiss() }
            catch {
                self.error = error.localizedDescription.contains("alias") || error.localizedDescription.contains("SendAs")
                    ? "Microsoft no deja enviar desde este alias todavía (activa «sending from aliases» en Exchange)." : error.localizedDescription
            }
            sending = false
        }
    }
    func runAI() {
        guard !busy else { return }
        busy = true
        Task {
            do {
                if let r = draft.replyTo {
                    draft.body = try await AIPrompts.reply(to: r, body: r.snip, idea: idea)
                } else {
                    guard !idea.isEmpty else { busy = false; return }
                    let (sub, body) = try await AIPrompts.write(idea: idea, to: draft.to)
                    if let sub, draft.subject.isEmpty { draft.subject = sub }
                    draft.body = body
                }
                withAnimation { showAI = false }
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    func useTemplate(_ t: [String: Any]) {
        let name = s.contacts.first { $0.e == draft.to.lowercased() }?.n.split(separator: " ").first.map(String.init) ?? ""
        let fill = { (x: String) in x.replacingOccurrences(of: "{{nombre}}", with: name.isEmpty ? "" : name).replacingOccurrences(of: "Hola ,", with: "Hola,") }
        if draft.subject.isEmpty, let sub = t["sub"] as? String { draft.subject = fill(sub) }
        draft.body = fill((t["body"] as? String) ?? "") + (draft.body.isEmpty ? "" : "\n\n" + draft.body)
    }
    func wrap(_ tok: String) {
        if draft.body.hasSuffix(tok) { return }
        draft.body += draft.body.isEmpty || draft.body.hasSuffix(" ") || draft.body.hasSuffix("\n") ? "\(tok)texto\(tok)" : " \(tok)texto\(tok)"
        focus = .body
    }
    func addFile(_ u: URL) {
        let ok = u.startAccessingSecurityScopedResource()
        defer { if ok { u.stopAccessingSecurityScopedResource() } }
        guard let d = try? Data(contentsOf: u) else { error = "No se pudo leer \(u.lastPathComponent)"; return }
        let type = UTType(filenameExtension: u.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        draft.atts.append(OutAtt(name: u.lastPathComponent, type: type, data: d.base64EncodedString(), size: d.count))
    }
    /// fotos del iPhone: JPG más ligero para que el correo no pese tanto
    func shrink(_ d: Data) -> Data {
        #if os(iOS)
        guard let img = UIImage(data: d) else { return d }
        let maxSide: CGFloat = 1800
        let k = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * k, height: img.size.height * k)
        let out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: 0.8) ?? d
        #else
        return d
        #endif
    }
}

/// Programar envío
struct ScheduleSheet: View {
    @Binding var when: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var custom = Date().addingTimeInterval(3600)
    var body: some View {
        let cal = Calendar.current, now = Date()
        let tomorrow9 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: now)!)!
        let monday9 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.nextDate(after: now, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)!)!
        let evening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now)!
        NavigationStack {
            List {
                Section {
                    opt("En 1 hora", "clock", now.addingTimeInterval(3600))
                    if evening > now.addingTimeInterval(1800) { opt("Esta tarde · 18:00", "sunset", evening) }
                    opt("Mañana · 9:00", "sunrise", tomorrow9)
                    opt("El lunes · 9:00", "calendar", monday9)
                }
                Section {
                    DatePicker("Elegir día y hora", selection: $custom, in: now..., displayedComponents: [.date, .hourAndMinute])
                        .font(Brand.f(15)).tint(Brand.wine)
                    Button { when = custom; dismiss() } label: {
                        Text("Programar a esa hora").font(Brand.f(15, .medium)).foregroundStyle(Brand.cream)
                            .frame(maxWidth: .infinity).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: 11).fill(Brand.wine))
                    }.buttonStyle(.plain).listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden).background(Brand.bg)
            .navigationTitle("Programar envío")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
    func opt(_ t: String, _ icon: String, _ d: Date) -> some View {
        Button { when = d; dismiss() } label: {
            HStack {
                Label(t, systemImage: icon).font(Brand.f(15)).foregroundStyle(Brand.fg)
                Spacer()
                Text(d.formatted(Date.FormatStyle(locale: Locale(identifier: "es_ES")).weekday(.abbreviated).day().hour().minute())).font(Brand.f(12.5)).foregroundStyle(Brand.fg3)
            }
        }
    }
}

// MARK: tracking
struct TrackList: View {
    @EnvironmentObject var s: Store
    var body: some View {
        List {
            HStack(spacing: 10) {
                stat("\(s.tracks.count)", "enviados")
                stat("\(s.tracks.filter { !$0.realOpens.isEmpty }.count)", "abiertos")
                stat("\(s.waiting)", "esperando")
            }.listRowSeparator(.hidden).listRowBackground(Color.clear)
            ForEach(s.tracks) { t in
                DisclosureGroup {
                    if t.realOpens.isEmpty { Text("Todavía no lo ha abierto.").font(Brand.f(13)).foregroundStyle(Brand.fg3) }
                    ForEach(Array(t.realOpens.enumerated()), id: \.offset) { _, o in
                        HStack { Image(systemName: "eye").foregroundStyle(Brand.at)
                            Text(ISO.parse(o.t).formatted(date: .abbreviated, time: .shortened)).font(Brand.f(13))
                            Spacer(); Text([o.d, o.p].compactMap { $0 }.joined(separator: " · ")).font(Brand.f(12)).foregroundStyle(Brand.fg3) }
                    }
                    ForEach(Array((t.clicks ?? []).enumerated()), id: \.offset) { _, c in
                        HStack { Image(systemName: "link").foregroundStyle(Brand.at)
                            Text(c.u ?? "enlace").font(Brand.f(12)).lineLimit(1); Spacer()
                            Text(ISO.parse(c.t).formatted(date: .omitted, time: .shortened)).font(Brand.f(12)).foregroundStyle(Brand.fg3) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(t.to.n).font(Brand.f(15, .medium)).lineLimit(1)
                            Spacer()
                            let n = t.realOpens.count
                            Text(n > 0 ? "Abierto \(n)×" : "Sin abrir").font(Brand.f(12, .medium))
                                .foregroundStyle(n > 0 ? Color.white : Brand.fg3).padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(n > 0 ? Brand.wine : Brand.line))
                        }
                        Text(t.sub).font(Brand.f(13.5)).foregroundStyle(Brand.fg2).lineLimit(1)
                        HStack(spacing: 8) {
                            Text(relTime(ISO.parse(t.date))).font(Brand.f(11.5)).foregroundStyle(Brand.fg3)
                            if t.replied == true { Label("Respondió", systemImage: "checkmark").font(Brand.f(11.5)).foregroundStyle(Brand.at) }
                            else if t.wait == true { Label("Esperando respuesta", systemImage: "clock").font(Brand.f(11.5)).foregroundStyle(Brand.fg3) }
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(Brand.bg)
        .refreshable { await s.refresh() }
        .navigationTitle("Seguimiento")
    }
    func stat(_ n: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(n).font(Brand.f(24, .medium)).foregroundStyle(Brand.at); Cap(l) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Brand.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }
}

// MARK: settings — como Gmail, pero Santoro
struct SettingsView: View {
    @EnvironmentObject var s: Store
    @AppStorage("set.defaultFrom") private var defaultFrom = ""
    @AppStorage("set.track") private var track = true
    @AppStorage("set.highlight") private var highlight = true
    @AppStorage("set.confirmSwipe") private var confirmSwipe = true
    @AppStorage("set.notifNew") private var notifNew = true
    @AppStorage("set.notifOpen") private var notifOpen = true
    @AppStorage("set.badge") private var badgeOn = true
    @AppStorage("set.theme") private var theme = "system"
    @State private var editTpl: TplEdit?
    @State private var askTrash = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    SantoroAvatar(size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.me?.name ?? "Hanif Hawlader").font(Brand.f(17, .medium))
                        Text(s.me?.email ?? "").font(Brand.f(13)).foregroundStyle(Brand.fg3)
                        Text(s.aiOn ? (s.me?.aiPro == true ? "IA: Claude" : "IA gratis activada") : "IA sin conectar").font(Brand.f(11.5)).foregroundStyle(s.aiOn ? Brand.at : Brand.fg3)
                    }
                }.padding(.vertical, 4)
            } header: { Cap("Cuenta") }

            Section {
                Picker(selection: $defaultFrom) {
                    Text("Automático").tag("")
                    ForEach(s.aliases) { a in Text(a.email).tag(a.email) }
                } label: { Label("Enviar desde", systemImage: "paperplane") }
                Toggle(isOn: $highlight) { Label("La IA resalta al enviar", systemImage: "sparkles") }.disabled(!s.aiOn)
                Toggle(isOn: $track) { Label("Seguimiento de aperturas y clics", systemImage: "eye") }
            } header: { Cap("Escribir") } footer: { Text("Valores por defecto de cada correo nuevo. Puedes cambiarlos en cada correo.").font(Brand.f(12)) }

            Section {
                SigPreview(k: "hanif", title: "Hanif Hawlader")
                SigPreview(k: "santoro", title: "Santoro")
                Link(destination: URL(string: BASE)!) { Label("Cambiar textos de la firma (web)", systemImage: "safari") }
            } header: { Cap("Firmas") } footer: { Text("La firma se elige sola según la dirección desde la que envías.").font(Brand.f(12)) }

            Section {
                ForEach(Array(s.templates.enumerated()), id: \.offset) { i, t in
                    Button { editTpl = TplEdit(index: i, name: t["name"] as? String ?? "", sub: t["sub"] as? String ?? "", body: t["body"] as? String ?? "") } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t["name"] as? String ?? "Plantilla").font(Brand.f(15)).foregroundStyle(Brand.fg)
                            Text(t["sub"] as? String ?? "").font(Brand.f(12)).foregroundStyle(Brand.fg3).lineLimit(1)
                        }
                    }
                }
                .onDelete { idx in var l = s.templates; l.remove(atOffsets: idx); Task { await s.saveTemplates(l) } }
                Button { editTpl = TplEdit(index: nil, name: "", sub: "", body: "Hola {{nombre}},\n\n") } label: { Label("Nueva plantilla", systemImage: "plus") }
            } header: { Cap("Plantillas") } footer: { Text("{{nombre}} se cambia solo por el nombre de la persona.").font(Brand.f(12)) }

            Section {
                Toggle(isOn: $confirmSwipe) { Label("Confirmar al deslizar", systemImage: "hand.draw") }
                HStack { Label("Deslizar →", systemImage: "arrow.right"); Spacer(); Text("Destacar · Leído").font(Brand.f(13)).foregroundStyle(Brand.fg3) }
                HStack { Label("Deslizar ←", systemImage: "arrow.left"); Spacer(); Text("Responder · Reenviar · Borrar").font(Brand.f(13)).foregroundStyle(Brand.fg3) }
            } header: { Cap("Bandeja") }

            Section {
                Toggle(isOn: $notifNew) { Label("Correo nuevo", systemImage: "bell") }
                Toggle(isOn: $notifOpen) { Label("Cuando abren tu correo", systemImage: "eye") }
                Toggle(isOn: $badgeOn) { Label("Número en el icono", systemImage: "app.badge") }
                    .onChange(of: badgeOn) { _, _ in s.badge() }
            } header: { Cap("Avisos") }

            Section {
                Picker(selection: $theme) {
                    Text("Automático").tag("system"); Text("Claro").tag("light"); Text("Oscuro").tag("dark")
                } label: { Label("Apariencia", systemImage: "circle.lefthalf.filled") }
            } header: { Cap("Aspecto") }

            Section {
                ForEach(Array(s.aliases.enumerated()), id: \.element.id) { i, a in
                    HStack(spacing: 12) {
                        Text(a.mark).font(Brand.f(11, .medium)).foregroundStyle(.white).frame(width: 32, height: 32).background(RoundedRectangle(cornerRadius: 8).fill(a.color))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.email).font(Brand.f(14.5))
                            Text(a.source == "ms" ? "● Activo en Microsoft" : a.source == "seen" ? "● Recibe correo" : "○ Falta crearlo en GoDaddy")
                                .font(Brand.f(11)).foregroundStyle(a.source == "manual" ? Brand.fg3 : Brand.at)
                        }
                    }.padding(.vertical, 2)
                }
            } header: { Cap("\(s.aliases.count) direcciones") } footer: {
                Text("Se leen solas de Microsoft y de tus correos. Para crear una nueva: GoDaddy → Email aliases.").font(Brand.f(12))
            }

            Section {
                Button { Task { await s.refresh() } } label: { Label("Sincronizar ahora", systemImage: "arrow.triangle.2.circlepath") }
                Button(role: .destructive) { askTrash = true } label: { Label("Vaciar papelera", systemImage: "trash") }
                HStack { Label("Versión", systemImage: "info.circle"); Spacer()
                    Text((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0").font(Brand.f(13)).foregroundStyle(Brand.fg3) }
            } header: { Cap("Avanzado") }

            Section {
                Button(role: .destructive) { s.logout() } label: { Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right") }
            }
        }
        .scrollContentBackground(.hidden).background(Brand.bg)
        .font(Brand.f(15)).tint(Brand.wine)
        .navigationTitle("Ajustes")
        .confirmationDialog("¿Vaciar la papelera? No se puede deshacer.", isPresented: $askTrash, titleVisibility: .visible) {
            Button("Vaciar papelera", role: .destructive) { Task { await s.emptyTrash() } }
        }
        .sheet(item: $editTpl) { t in TemplateEditor(t: t).environmentObject(s) }
    }
}

struct TplEdit: Identifiable { var id = UUID(); var index: Int?; var name: String; var sub: String; var body: String }

struct TemplateEditor: View {
    @EnvironmentObject var s: Store
    @Environment(\.dismiss) private var dismiss
    @State var t: TplEdit
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre de la plantilla", text: $t.name)
                TextField("Asunto", text: $t.sub)
                TextEditor(text: $t.body).frame(minHeight: 220)
            }
            .font(Brand.f(15)).scrollContentBackground(.hidden).background(Brand.bg)
            .navigationTitle(t.index == nil ? "Nueva plantilla" : "Editar plantilla")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var l = s.templates
                        var item: [String: Any] = t.index.map { l[$0] } ?? ["id": "t" + String(Int(Date().timeIntervalSince1970)), "cat": "cli", "id_": "santoro"]
                        item["name"] = t.name.isEmpty ? "Plantilla" : t.name; item["sub"] = t.sub; item["body"] = t.body
                        if let i = t.index { l[i] = item } else { l.append(item) }
                        Task { await s.saveTemplates(l) }
                        dismiss()
                    }
                }
            }
        }
        .tint(Brand.at)
    }
}

/// Vista previa de la firma tal como sale en el correo (cabecera animada)
struct SigPreview: View {
    let k: String
    let title: String
    @State private var data: Data?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Brand.f(13, .medium)).foregroundStyle(Brand.fg2)
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Brand.wine)
                if data != nil { GIFView(data: data).clipShape(RoundedRectangle(cornerRadius: 12)) }
                else { ProgressView().tint(Brand.cream) }
            }
            .frame(width: 250, height: 100)
        }
        .padding(.vertical, 4)
        .task {
            guard data == nil, let u = URL(string: BASE + "/brand/head-\(k).gif") else { return }
            data = try? await URLSession.shared.data(from: u).0
        }
    }
}
