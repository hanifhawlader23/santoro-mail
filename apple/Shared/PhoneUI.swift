import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: logo animado (el jinete se balancea, como en la web)
struct SwayLogo: View {
    var size: CGFloat
    var cream = true
    @State private var on = false
    var body: some View {
        Image(cream ? "RiderCream" : "RiderWine").resizable().scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(on ? 6 : -6), anchor: .bottom)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// Aviso pequeño arriba con el logo moviéndose: Sincronizando… · Enviando… · Enviado
struct SyncPill: View {
    @EnvironmentObject var s: Store
    var body: some View {
        ZStack {
            if let a = s.activity {
                HStack(spacing: 9) {
                    ZStack {
                        Circle().fill(Brand.cream.opacity(0.14)).frame(width: 28, height: 28)
                        if a == "Enviado" || a == "Programado" || a == "Borrador guardado" {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Brand.cream)
                        } else { SwayLogo(size: 22) }
                    }
                    Text(a).font(Brand.f(13.5, .medium)).foregroundStyle(Brand.cream)
                }
                .padding(.leading, 6).padding(.trailing, 16).padding(.vertical, 5)
                .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#74253B"), Brand.wine], startPoint: .top, endPoint: .bottom)))
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .shadow(color: Brand.wine.opacity(0.35), radius: 10, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: s.activity)
        .padding(.top, 2)
        .allowsHitTesting(false)
    }
}

/// Pantalla de inicio mientras llega el correo
struct Splash: View {
    var body: some View {
        ZStack {
            Brand.wine.ignoresSafeArea()
            VStack(spacing: 14) {
                SwayLogo(size: 130)
                Text("SANTORO").font(Brand.f(21, .medium)).tracking(9).foregroundStyle(Brand.cream).padding(.top, 8)
                Text("MAIL").font(Brand.f(11.5)).tracking(5).foregroundStyle(Brand.cream.opacity(0.6))
                HStack(spacing: 8) {
                    ProgressView().tint(Brand.cream).controlSize(.small)
                    Text("Sincronizando tu correo…").font(Brand.f(13)).foregroundStyle(Brand.cream.opacity(0.8))
                }.padding(.top, 22)
            }
        }
    }
}

// MARK: botón del menú (cuadrado vino con relieve)
struct MenuButton: View {
    var n: Int
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 3.5) {
                    Capsule().frame(width: 16, height: 2.2)
                    Capsule().frame(width: 10, height: 2.2)
                    Capsule().frame(width: 13, height: 2.2)
                }
                .foregroundStyle(Brand.cream)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11).fill(LinearGradient(colors: [Color(hex: "#7E2D44"), Brand.wine, Color(hex: "#45121F")], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .shadow(color: Brand.wine.opacity(0.4), radius: 4, y: 2)
                if n > 0 {
                    Circle().fill(Brand.cream).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Brand.wine, lineWidth: 1.2))
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Menú")
    }
}

#if os(iOS)
// MARK: iPhone — lista a pantalla completa + menú lateral ligero
struct PhoneMain: View {
    @EnvironmentObject var s: Store
    @State private var menu = false
    @State private var path = NavigationPath()
    init() {
        // títulos en El Messiri, como el resto de la marca
        let wine = UIColor(red: 91 / 255, green: 26 / 255, blue: 44 / 255, alpha: 1)
        let ink = UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.86, green: 0.62, blue: 0.68, alpha: 1) : wine }
        let a = UINavigationBarAppearance(); a.configureWithTransparentBackground()
        if let big = UIFont(name: "ElMessiri-Medium", size: 30), let small = UIFont(name: "ElMessiri-Medium", size: 17) {
            a.largeTitleTextAttributes = [.font: big, .foregroundColor: ink]
            a.titleTextAttributes = [.font: small, .foregroundColor: ink]
        }
        UINavigationBar.appearance().standardAppearance = a
        UINavigationBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $path) {
                Group {
                    switch s.section {
                    case .mail: MailList(sel: .constant(nil))
                    case .track: TrackList()
                    case .settings: SettingsView()
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        if !home {
                            Button { goHome() } label: {
                                Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(Brand.at)
                                    .frame(width: 34, height: 34)
                            }.buttonStyle(.plain).accessibilityLabel("Volver a la bandeja")
                        }
                        MenuButton(n: s.unread()) { open() }
                    }
                }
                .navigationDestination(for: String.self) { id in
                    if let m = s.find(id) { Reader(mail: m) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if s.section == .mail && path.isEmpty && !menu { ComposeFab() }
            }
            // deslizar desde el borde izquierdo: vuelve a «Todas» (o abre el menú si ya estás ahí), como en iPhone
            .overlay(alignment: .leading) {
                if path.isEmpty && !menu {
                    Color.clear.frame(width: 22).frame(maxHeight: .infinity).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 15).onEnded { v in
                            guard v.translation.width > 60 else { return }
                            if home { open() } else { goHome() }
                        })
                }
            }

            if menu {
                Color.black.opacity(0.30).ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                SideMenu(close: close)
                    .transition(.move(edge: .leading))
                    .zIndex(2)
            }
        }
        .overlay(alignment: .top) { SyncPill() }
        .sheet(item: $s.compose) { d in ComposeView(draft: d).environmentObject(s) }
        .onChange(of: s.section) { _, _ in path = NavigationPath() }
        #if DEBUG
        .onAppear {
            let a = ProcessInfo.processInfo.arguments
            if a.contains("-menu") { menu = true }
            if a.contains("-compose") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { s.composeNew(to: "mar") } }
            if a.contains("-settings") { s.section = .settings }
        }
        #endif
        .onChange(of: s.folder) { _, _ in path = NavigationPath() }
        .onChange(of: s.alias) { _, _ in path = NavigationPath() }
    }
    var home: Bool { s.section == .mail && s.folder == "inbox" && s.alias == nil }
    func goHome() { withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { s.section = .mail; s.folder = "inbox"; s.alias = nil } }
    func open() { withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { menu = true } }
    func close() { withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { menu = false } }
}

/// Botón flotante para escribir
struct ComposeFab: View {
    @EnvironmentObject var s: Store
    @State private var pressed = false
    var body: some View {
        Button { s.composeNew() } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil").font(.system(size: 17, weight: .semibold))
                Text("Escribir").font(Brand.f(15, .medium))
            }
            .foregroundStyle(Brand.cream)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(hex: "#7E2D44"), Brand.wine], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: Brand.wine.opacity(0.45), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 18).padding(.bottom, 84)
        .transition(.scale.combined(with: .opacity))
    }
}

struct SideMenu: View {
    @EnvironmentObject var s: Store
    var close: () -> Void
    @GestureState private var drag: CGFloat = 0

    var body: some View {
        let w = min(UIScreen.main.bounds.width * 0.8, 320)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                SantoroAvatar(size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SANTORO").font(Brand.f(16, .medium)).tracking(5).foregroundStyle(Brand.at)
                    Text("Hanif Hawlader · Mail").font(Brand.f(11.5)).foregroundStyle(Brand.fg3)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Brand.fg2)
                        .frame(width: 30, height: 30).background(Circle().fill(Brand.line))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 16)

            Button { close(); s.composeNew() } label: {
                HStack(spacing: 8) { Image(systemName: "square.and.pencil"); Text("Redactar").font(Brand.f(15, .medium)) }
                    .foregroundStyle(Brand.cream).frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [Color(hex: "#7E2D44"), Brand.wine], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: Brand.wine.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain).padding(.horizontal, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    head("Bandejas")
                    item(AnyView(Image(systemName: "tray.2.fill").foregroundStyle(Brand.at)), "Todas", s.unread(),
                         s.section == .mail && s.folder == "inbox" && s.alias == nil) { s.section = .mail; s.folder = "inbox"; s.alias = nil }
                    ForEach(s.aliases) { a in
                        item(AnyView(Text(a.mark).font(Brand.f(9.5, .medium)).foregroundStyle(.white).frame(width: 24, height: 20).background(RoundedRectangle(cornerRadius: 6).fill(a.color))),
                             a.local + "@", s.unread(a.email), s.section == .mail && s.alias == a.email) { s.section = .mail; s.folder = "inbox"; s.alias = a.email }
                    }
                    head("Carpetas")
                    ForEach(FOLDERS.dropFirst(), id: \.0) { f in
                        item(AnyView(Image(systemName: f.2).foregroundStyle(Brand.fg2)), f.1, f.0 == "drafts" ? (s.box["drafts"]?.count ?? 0) : 0,
                             s.section == .mail && s.folder == f.0 && s.alias == nil) { s.section = .mail; s.folder = f.0; s.alias = nil }
                    }
                    head("Herramientas")
                    item(AnyView(Image(systemName: "eye").foregroundStyle(Brand.fg2)), "Seguimiento", s.waiting, s.section == .track) { s.section = .track }
                    item(AnyView(Image(systemName: "gearshape").foregroundStyle(Brand.fg2)), "Ajustes", 0, s.section == .settings) { s.section = .settings }
                }
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 20)
            }
        }
        .frame(width: w)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 28, topTrailingRadius: 28)
                .fill(Brand.bg).ignoresSafeArea()
                .shadow(color: .black.opacity(0.22), radius: 22, x: 8)
        )
        .offset(x: min(0, drag))
        .gesture(DragGesture(minimumDistance: 12)
            .updating($drag) { v, st, _ in st = v.translation.width }
            .onEnded { v in if v.translation.width < -70 { close() } })
    }

    func head(_ t: String) -> some View { Cap(t).padding(.horizontal, 10).padding(.top, 16).padding(.bottom, 4) }

    func item(_ icon: AnyView, _ title: String, _ n: Int, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { action(); close() } label: {
            HStack(spacing: 11) {
                icon.frame(width: 26)
                Text(title).font(Brand.f(15, on ? .medium : .regular)).foregroundStyle(on ? Brand.at : Brand.fg).lineLimit(1)
                Spacer()
                if n > 0 {
                    Text("\(n)").font(Brand.f(11.5, .semibold)).foregroundStyle(on ? Brand.cream : Brand.at)
                        .padding(.horizontal, 7).padding(.vertical, 1.5)
                        .background(Capsule().fill(on ? Brand.wine : Brand.wine.opacity(0.10)))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7.5)
            .background(RoundedRectangle(cornerRadius: 11).fill(on ? Brand.wine.opacity(0.10) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
