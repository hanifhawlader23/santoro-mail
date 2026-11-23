import SwiftUI

// MARK: compose
struct ComposeView: View {
    @EnvironmentObject var s: Store
    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft
    @State private var track = true
    @State private var highlight = true
    @State private var idea = ""
    @State private var busy = false
    @State private var sending = false
    @State private var error: String?
    @FocusState private var bodyFocus: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    field("De") {
                        Picker("", selection: $draft.from) {
                            ForEach(s.aliases) { a in Text("\(a.ident == "hanif" ? "Hanif Hawlader" : "Santoro") — \(a.email)").tag(a.email) }
                        }.labelsHidden().pickerStyle(.menu).tint(Brand.fg)
                    }
                    field("Para") {
                        TextField("nombre@empresa.com", text: $draft.to).font(Brand.f(16))
                            #if os(iOS)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                            #endif
                    }
                    field("Asunto") { TextField("", text: $draft.subject).font(Brand.f(16)) }

                    if s.aiOn {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundStyle(Brand.at)
                            TextField(draft.replyTo == nil ? "Dile a la IA qué quieres escribir…" : "¿Qué quieres responder? (opcional)", text: $idea)
                                .font(Brand.f(14)).onSubmit(runAI)
                            Button(action: runAI) {
                                if busy { ProgressView().controlSize(.small) } else { Text("Escribir").font(Brand.f(13, .medium)) }
                            }
                            .buttonStyle(.borderedProminent).tint(Brand.wine).disabled(busy)
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Brand.wine.opacity(0.06))).padding(.vertical, 10)
                    }

                    HStack(spacing: 6) {
                        fmt("B", bold: true) { wrap("**") }
                        fmt("A", wine: true) { wrap("==") }
                        if s.aiOn {
                            Button {
                                busy = true
                                Task {
                                    let plain = AIPrompts.strip(draft.body)
                                    if let r = try? await AIPrompts.highlight(plain) { draft.body = r } else { error = "La IA no pudo resaltar ahora." }
                                    busy = false
                                }
                            } label: { Label("Resaltar con IA", systemImage: "sparkles").font(Brand.f(12.5, .medium)) }
                            .buttonStyle(.bordered).tint(Brand.at)
                        }
                        Spacer()
                    }.padding(.top, 6)

                    TextEditor(text: $draft.body)
                        .font(Brand.f(16)).frame(minHeight: 240).scrollContentBackground(.hidden)
                        .focused($bodyFocus)
                        .padding(.vertical, 6)
                    if draft.body.contains("**") || draft.body.contains("==") {
                        VStack(alignment: .leading, spacing: 6) {
                            Cap("Así se verá")
                            Text(markup(draft.body)).font(Brand.f(15)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Brand.card))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $highlight) { Label("La IA resalta lo importante al enviar", systemImage: "sparkles").font(Brand.f(14)) }
                            .disabled(!s.aiOn)
                        Toggle(isOn: $track) { Label("Saber si lo abre y si hace clic", systemImage: "eye").font(Brand.f(14)) }
                        Text("Tu firma \(s.aliases.first { $0.email == draft.from }?.ident == "hanif" ? "Hanif Hawlader" : "Santoro") se añade sola al enviar.")
                            .font(Brand.f(12)).foregroundStyle(Brand.fg3)
                    }
                    .tint(Brand.wine).padding(.top, 14)

                    if let error { Text(error).font(Brand.f(13)).foregroundStyle(.red).padding(.top, 8) }
                }
                .padding(18)
            }
            .background(Brand.bg)
            .navigationTitle(draft.replyTo == nil ? "Nuevo correo" : "Responder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sending = true; error = nil
                        Task {
                            do { try await s.send(draft, track: track, highlight: highlight); dismiss() }
                            catch { self.error = error.localizedDescription.contains("alias") || error.localizedDescription.contains("SendAs")
                                ? "Microsoft no deja enviar desde este alias todavía (activa «sending from aliases» en Exchange)." : error.localizedDescription }
                            sending = false
                        }
                    } label: {
                        if sending { ProgressView() } else { Label("Enviar", systemImage: "paperplane.fill").font(Brand.f(15, .medium)) }
                    }
                    .disabled(sending || draft.to.isEmpty)
                }
            }
        }
        .tint(Brand.at)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 640)
        #endif
        .onAppear { if draft.to.isEmpty == false { bodyFocus = true } }
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
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    func wrap(_ tok: String) {
        // no selection API on every OS: add the marks around the last line, or start a new marked part
        if draft.body.hasSuffix(tok) { return }
        draft.body += draft.body.isEmpty || draft.body.hasSuffix(" ") || draft.body.hasSuffix("\n") ? "\(tok)texto\(tok)" : " \(tok)texto\(tok)"
    }
    func fmt(_ t: String, bold: Bool = false, wine: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(Brand.f(15, .semibold)).foregroundStyle(wine ? Brand.at : Brand.fg)
                .frame(width: 34, height: 30).background(RoundedRectangle(cornerRadius: 7).fill(Brand.card))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Brand.line))
        }.buttonStyle(.plain)
    }
    func field<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) { Text(label).font(Brand.f(13)).foregroundStyle(Brand.fg3).frame(width: 56, alignment: .leading); c() }
                .padding(.vertical, 10)
            Divider()
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

// MARK: settings
struct SettingsView: View {
    @EnvironmentObject var s: Store
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    SantoroAvatar(size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.me?.name ?? "Hanif Hawlader").font(Brand.f(17, .medium))
                        Text(s.me?.email ?? "").font(Brand.f(13)).foregroundStyle(Brand.fg3)
                    }
                }.padding(.vertical, 4)
            } header: { Cap("Cuenta") }

            Section {
                ForEach(Array(s.aliases.enumerated()), id: \.element.id) { i, a in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(Brand.f(12)).foregroundStyle(Brand.fg3).frame(width: 16)
                        Text(a.mark).font(Brand.f(11, .medium)).foregroundStyle(.white).frame(width: 32, height: 32).background(RoundedRectangle(cornerRadius: 8).fill(a.color))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.email).font(Brand.f(14.5))
                            Text("\(a.label) · \(a.ident == "hanif" ? "Hanif Hawlader" : "Santoro")").font(Brand.f(12)).foregroundStyle(Brand.fg3)
                            Text(a.source == "ms" ? "● Activo en Microsoft" : a.source == "seen" ? "● Recibe correo" : "○ Falta crearlo en GoDaddy")
                                .font(Brand.f(11)).foregroundStyle(a.source == "manual" ? Brand.fg3 : Brand.at)
                        }
                    }.padding(.vertical, 3)
                }
            } header: { Cap("\(s.aliases.count) direcciones") } footer: {
                Text("Se leen solas de Microsoft y de tus correos. Para crear uno nuevo: GoDaddy → Email aliases, con el mismo nombre.").font(Brand.f(12))
            }

            Section {
                HStack { Label("Inteligencia artificial", systemImage: "sparkles"); Spacer()
                    Text(s.aiOn ? (s.me?.aiPro == true ? "Claude" : "Gratis") : "Sin conectar").font(Brand.f(13)).foregroundStyle(s.aiOn ? Brand.at : Brand.fg3) }
                Link(destination: URL(string: BASE)!) { Label("Firmas, plantillas y automatizaciones (web)", systemImage: "safari") }
            } header: { Cap("Más") }

            Section {
                Button(role: .destructive) { s.logout() } label: { Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right") }
            }
        }
        .scrollContentBackground(.hidden).background(Brand.bg)
        .font(Brand.f(15))
        .navigationTitle("Ajustes")
    }
}
